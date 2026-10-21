import asyncio
import json
import math
import os
import time
from collections import deque

from starlette.types import ASGIApp, Receive, Scope, Send


def _positive_int(name: str, default: int) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except (TypeError, ValueError):
        return default
    return value if value > 0 else default


class PublicAPIGuardrails:
    """Process-local safeguards for public chat-completion requests."""

    def __init__(
        self,
        app: ASGIApp,
        max_body_bytes: int | None = None,
        requests_per_minute: int | None = None,
        max_concurrent_requests: int | None = None,
        max_concurrent_per_ip: int = 2,
        max_tokens: int | None = None,
    ):
        self.app = app
        self.max_body_bytes = (
            max_body_bytes
            if max_body_bytes is not None
            else _positive_int("MODELOPS_MAX_REQUEST_BYTES", 65536)
        )
        self.requests_per_minute = (
            requests_per_minute
            if requests_per_minute is not None
            else _positive_int("MODELOPS_RATE_LIMIT_PER_MINUTE", 12)
        )
        self.max_concurrent_requests = (
            max_concurrent_requests
            if max_concurrent_requests is not None
            else _positive_int("MODELOPS_MAX_CONCURRENT_GENERATIONS", 3)
        )
        self.max_concurrent_per_ip = max(1, max_concurrent_per_ip)
        self.max_tokens = (
            max_tokens
            if max_tokens is not None
            else _positive_int("MODELOPS_MAX_OUTPUT_TOKENS", 512)
        )

        self._hits: dict[str, deque[float]] = {}
        self._active_by_ip: dict[str, int] = {}
        self._active_total = 0
        self._checks = 0
        self._lock = asyncio.Lock()

    async def _reject(
        self,
        send: Send,
        status: int,
        detail: str,
        retry_after: int | None = None,
    ) -> None:
        body = json.dumps({"detail": detail}).encode("utf-8")
        headers = [
            (b"content-type", b"application/json"),
            (b"content-length", str(len(body)).encode("ascii")),
            (b"cache-control", b"no-store"),
        ]

        if retry_after is not None:
            headers.append(
                (b"retry-after", str(retry_after).encode("ascii"))
            )

        await send({
            "type": "http.response.start",
            "status": status,
            "headers": headers,
        })
        await send({
            "type": "http.response.body",
            "body": body,
            "more_body": False,
        })

    async def __call__(
        self,
        scope: Scope,
        receive: Receive,
        send: Send,
    ) -> None:
        # Leave health, readiness, model discovery and the website unchanged.
        if (
            scope.get("type") != "http"
            or scope.get("method") != "POST"
            or scope.get("path") != "/v1/chat/completions"
        ):
            await self.app(scope, receive, send)
            return

        headers = {
            key.lower(): value
            for key, value in scope.get("headers", [])
        }

        content_length = headers.get(b"content-length")
        if content_length:
            try:
                if int(content_length) > self.max_body_bytes:
                    await self._reject(
                        send, 413, "Request body exceeds the size limit."
                    )
                    return
            except ValueError:
                pass

        # Read the request once, enforcing the limit even for chunked bodies.
        chunks = []
        total_bytes = 0

        while True:
            message = await receive()

            if message["type"] == "http.disconnect":
                return

            if message["type"] != "http.request":
                continue

            chunk = message.get("body", b"")
            total_bytes += len(chunk)

            if total_bytes > self.max_body_bytes:
                await self._reject(
                    send, 413, "Request body exceeds the size limit."
                )
                return

            chunks.append(chunk)

            if not message.get("more_body", False):
                break

        body = b"".join(chunks)

        # Enforce a server-side output-token ceiling before forwarding upstream.
        try:
            payload = json.loads(body) if body else None
        except (ValueError, UnicodeDecodeError):
            payload = None

        if isinstance(payload, dict):
            for field in ("max_tokens", "max_completion_tokens"):
                value = payload.get(field)

                if isinstance(value, bool) or not isinstance(value, (int, float)):
                    continue

                if value <= 0:
                    await self._reject(
                        send, 400, f"{field} must be positive."
                    )
                    return

                if value > self.max_tokens:
                    await self._reject(
                        send,
                        400,
                        f"{field} exceeds the server limit of "
                        f"{self.max_tokens}.",
                    )
                    return

        # ALB appends the connecting client's address to X-Forwarded-For.
        # Use the rightmost entry when behind the existing ALB.
        forwarded = headers.get(b"x-forwarded-for", b"")
        forwarded_ips = forwarded.decode(
            "latin-1", errors="replace"
        ).split(",")
        client_ip = forwarded_ips[-1].strip() if forwarded_ips else ""

        if not client_ip:
            client = scope.get("client")
            client_ip = client[0] if client else "unknown"

        now = time.monotonic()
        denial = None
        reserved = False

        async with self._lock:
            history = self._hits.setdefault(client_ip, deque())

            while history and now - history[0] >= 60:
                history.popleft()

            if len(history) >= self.requests_per_minute:
                wait = max(
                    1, math.ceil(60 - (now - history[0]))
                )
                denial = (
                    429,
                    "Chat request rate limit exceeded.",
                    wait,
                )
            else:
                history.append(now)
                active = self._active_by_ip.get(client_ip, 0)

                if active >= self.max_concurrent_per_ip:
                    denial = (
                        429,
                        "Too many simultaneous requests from this client.",
                        5,
                    )
                elif self._active_total >= self.max_concurrent_requests:
                    denial = (
                        503,
                        "The inference service is busy. Try again shortly.",
                        5,
                    )
                else:
                    self._active_total += 1
                    self._active_by_ip[client_ip] = active + 1
                    reserved = True

            self._checks += 1

            # Bound stale per-IP bookkeeping as clients come and go.
            if self._checks % 128 == 0:
                for ip, entries in list(self._hits.items()):
                    while entries and now - entries[0] >= 60:
                        entries.popleft()

                    if not entries and ip not in self._active_by_ip:
                        self._hits.pop(ip, None)

        if denial is not None:
            status, detail, retry_after = denial
            await self._reject(send, status, detail, retry_after)
            return

        # Replay the already-read body so FastAPI receives the original JSON.
        first_message = True

        async def replay_receive():
            nonlocal first_message

            if first_message:
                first_message = False
                return {
                    "type": "http.request",
                    "body": body,
                    "more_body": False,
                }

            return await receive()

        try:
            # The reservation remains held until the response stream completes.
            await self.app(scope, replay_receive, send)
        finally:
            if reserved:
                async with self._lock:
                    self._active_total -= 1
                    remaining = self._active_by_ip.get(client_ip, 1) - 1

                    if remaining <= 0:
                        self._active_by_ip.pop(client_ip, None)
                    else:
                        self._active_by_ip[client_ip] = remaining
