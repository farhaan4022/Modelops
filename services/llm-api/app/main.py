import json
import os
from contextlib import asynccontextmanager
from typing import Any

import httpx
from fastapi import Depends, FastAPI, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse
from starlette.background import BackgroundTask
from app.guardrails import PublicAPIGuardrails


VLLM_BASE_URL = os.getenv(
    "VLLM_BASE_URL",
    "http://qwen-vllm.modelops.svc.cluster.local:8000",
).rstrip("/")

DEFAULT_MODEL = os.getenv(
    "DEFAULT_MODEL",
    "Qwen/Qwen2.5-1.5B-Instruct",
)

REQUEST_TIMEOUT_SECONDS = float(
    os.getenv("REQUEST_TIMEOUT_SECONDS", "120")
)

MAX_REQUEST_BYTES = 2 * 1024 * 1024

HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "content-length",
    "host",
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    timeout = httpx.Timeout(
        REQUEST_TIMEOUT_SECONDS,
        connect=5.0,
    )

    app.state.http_client = httpx.AsyncClient(
        timeout=timeout,
        follow_redirects=False,
    )

    try:
        yield
    finally:
        await app.state.http_client.aclose()


app = FastAPI(
    title="ModelOps LLM API",
    version="1.0.0",
    description="API gateway for the ModelOps vLLM inference service.",
    lifespan=lifespan,
)
app.add_middleware(PublicAPIGuardrails)


def get_http_client(request: Request) -> httpx.AsyncClient:
    return request.app.state.http_client


def safe_response_headers(
    headers: httpx.Headers,
) -> dict[str, str]:
    return {
        name: value
        for name, value in headers.items()
        if name.lower() not in HOP_BY_HOP_HEADERS
    }


@app.get("/")
async def root() -> dict[str, str]:
    return {
        "service": "modelops-llm-api",
        "status": "ok",
        "health": "/health",
        "readiness": "/ready",
    }


@app.get("/health")
async def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": "modelops-llm-api",
    }


@app.get("/ready")
async def readiness(
    client: httpx.AsyncClient = Depends(get_http_client),
) -> JSONResponse:
    try:
        upstream = await client.get(f"{VLLM_BASE_URL}/health")

        if upstream.is_success:
            return JSONResponse(
                {"status": "ready", "model_service": "reachable"},
                status_code=200,
            )

        return JSONResponse(
            {
                "status": "not_ready",
                "reason": "model_service_unhealthy",
            },
            status_code=503,
        )

    except httpx.RequestError:
        return JSONResponse(
            {
                "status": "not_ready",
                "reason": "model_service_unreachable",
            },
            status_code=503,
        )


async def forward_request(
    *,
    method: str,
    path: str,
    client: httpx.AsyncClient,
    body: bytes | None = None,
    stream: bool = False,
    query: str = "",
    content_type: str | None = None,
) -> Response:
    url = f"{VLLM_BASE_URL}{path}"

    headers: dict[str, str] = {
        "accept": "application/json, text/event-stream",
    }

    if content_type:
        headers["content-type"] = content_type

    if stream:
        headers["accept"] = "text/event-stream"

    request = client.build_request(
        method,
        url,
        content=body,
        headers=headers,
        params=query,
    )

    try:
        upstream = await client.send(request, stream=True)

    except httpx.TimeoutException:
        return JSONResponse(
            {"error": {"message": "Model inference timed out."}},
            status_code=504,
        )

    except httpx.RequestError:
        return JSONResponse(
            {"error": {"message": "Model inference service unavailable."}},
            status_code=502,
        )

    response_headers = safe_response_headers(upstream.headers)

    if stream and upstream.status_code < 400:
        return StreamingResponse(
            upstream.aiter_raw(),
            status_code=upstream.status_code,
            headers=response_headers,
            background=BackgroundTask(upstream.aclose),
        )

    try:
        response_body = await upstream.aread()

        return Response(
            content=response_body,
            status_code=upstream.status_code,
            headers=response_headers,
        )
    finally:
        await upstream.aclose()


@app.get("/v1/models")
async def list_models(
    request: Request,
    client: httpx.AsyncClient = Depends(get_http_client),
) -> Response:
    return await forward_request(
        method="GET",
        path="/v1/models",
        client=client,
        query=request.url.query,
    )


@app.post("/v1/chat/completions")
async def chat_completions(
    request: Request,
    client: httpx.AsyncClient = Depends(get_http_client),
) -> Response:
    content_length = request.headers.get("content-length")

    if content_length:
        try:
            if int(content_length) > MAX_REQUEST_BYTES:
                return JSONResponse(
                    {"error": {"message": "Request body is too large."}},
                    status_code=413,
                )
        except ValueError:
            return JSONResponse(
                {"error": {"message": "Invalid Content-Length."}},
                status_code=400,
            )

    body = await request.body()

    if len(body) > MAX_REQUEST_BYTES:
        return JSONResponse(
            {"error": {"message": "Request body is too large."}},
            status_code=413,
        )

    try:
        payload: Any = json.loads(body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return JSONResponse(
            {"error": {"message": "Request body must be valid JSON."}},
            status_code=400,
        )

    if not isinstance(payload, dict):
        return JSONResponse(
            {"error": {"message": "Request body must be a JSON object."}},
            status_code=422,
        )

    messages = payload.get("messages")

    if not isinstance(messages, list) or not messages:
        return JSONResponse(
            {
                "error": {
                    "message": "A non-empty messages array is required."
                }
            },
            status_code=422,
        )

    model = payload.get("model", DEFAULT_MODEL)

    if not isinstance(model, str) or not model.strip():
        return JSONResponse(
            {"error": {"message": "model must be a non-empty string."}},
            status_code=422,
        )

    stream = payload.get("stream", False)

    if not isinstance(stream, bool):
        return JSONResponse(
            {"error": {"message": "stream must be a boolean."}},
            status_code=422,
        )

    payload["model"] = model

    return await forward_request(
        method="POST",
        path="/v1/chat/completions",
        client=client,
        body=json.dumps(payload).encode("utf-8"),
        stream=stream,
        content_type="application/json",
    )
