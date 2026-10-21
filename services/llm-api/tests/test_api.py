import asyncio
import json
from contextlib import contextmanager

import httpx
from fastapi.testclient import TestClient

from app.main import app, get_http_client


@contextmanager
def client_with_mock(handler):
    upstream_client = httpx.AsyncClient(
        transport=httpx.MockTransport(handler),
        base_url="http://mock-upstream",
    )

    app.dependency_overrides[get_http_client] = (
        lambda: upstream_client
    )

    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
        asyncio.run(upstream_client.aclose())


def test_health():
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_models_proxy():
    def handler(request):
        assert request.url.path == "/v1/models"

        return httpx.Response(
            200,
            json={
                "object": "list",
                "data": [{"id": "Qwen/Qwen2.5-1.5B-Instruct"}],
            },
        )

    with client_with_mock(handler) as client:
        response = client.get("/v1/models")

    assert response.status_code == 200
    assert response.json()["object"] == "list"


def test_non_streaming_chat_proxy():
    def handler(request):
        assert request.url.path == "/v1/chat/completions"

        payload = json.loads(request.content)
        assert payload["model"] == "Qwen/Qwen2.5-1.5B-Instruct"
        assert payload["messages"][0]["content"] == "Hello"

        return httpx.Response(
            200,
            json={
                "id": "chatcmpl-test",
                "object": "chat.completion",
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": "Hello from the mock model.",
                        },
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    with client_with_mock(handler) as client:
        response = client.post(
            "/v1/chat/completions",
            json={
                "messages": [
                    {"role": "user", "content": "Hello"}
                ]
            },
        )

    assert response.status_code == 200
    assert (
        response.json()["choices"][0]["message"]["content"]
        == "Hello from the mock model."
    )


class MockAsyncByteStream(httpx.AsyncByteStream):
    """Provide an unconsumed asynchronous HTTP response stream."""

    def __init__(self, body: bytes):
        self.body = body

    async def __aiter__(self):
        yield self.body

    async def aclose(self):
        pass


def test_streaming_chat_proxy():
    stream_body = (
        b'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n'
        b"data: [DONE]\n\n"
    )

    def handler(request):
        payload = json.loads(request.content)
        assert payload["stream"] is True

        return httpx.Response(
            200,
            stream=MockAsyncByteStream(stream_body),
            headers={"content-type": "text/event-stream"},
        )

    with client_with_mock(handler) as client:
        response = client.post(
            "/v1/chat/completions",
            json={
                "model": "Qwen/Qwen2.5-1.5B-Instruct",
                "messages": [
                    {"role": "user", "content": "Hello"}
                ],
                "stream": True,
            },
        )

    assert response.status_code == 200
    assert "text/event-stream" in response.headers["content-type"]
    assert "Hello" in response.text
    assert "data: [DONE]" in response.text


def test_invalid_messages_rejected_without_upstream_call():
    def handler(request):
        raise AssertionError("Upstream must not be called.")

    with client_with_mock(handler) as client:
        response = client.post(
            "/v1/chat/completions",
            json={"messages": []},
        )

    assert response.status_code == 422


def test_readiness_checks_upstream():
    def handler(request):
        assert request.url.path == "/health"
        return httpx.Response(200, json={"status": "ok"})

    with client_with_mock(handler) as client:
        response = client.get("/ready")

    assert response.status_code == 200
    assert response.json()["status"] == "ready"
