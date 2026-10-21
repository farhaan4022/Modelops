from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from app.guardrails import PublicAPIGuardrails


def make_client(
    *,
    max_body_bytes=65536,
    requests_per_minute=12,
    max_concurrent_requests=3,
    max_tokens=512,
):
    app = FastAPI()

    app.add_middleware(
        PublicAPIGuardrails,
        max_body_bytes=max_body_bytes,
        requests_per_minute=requests_per_minute,
        max_concurrent_requests=max_concurrent_requests,
        max_tokens=max_tokens,
    )

    @app.post("/v1/chat/completions")
    async def chat(request: Request):
        return {"received": await request.json()}

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    return TestClient(app)


def test_valid_chat_request_passes():
    client = make_client()
    response = client.post(
        "/v1/chat/completions",
        json={"messages": [{"role": "user", "content": "Hello"}],
              "max_tokens": 8},
    )

    assert response.status_code == 200
    assert response.json()["received"]["max_tokens"] == 8


def test_oversized_chat_body_is_rejected():
    client = make_client(max_body_bytes=128)
    response = client.post(
        "/v1/chat/completions",
        json={"messages": [{"role": "user", "content": "x" * 300}]},
    )

    assert response.status_code == 413


def test_server_token_ceiling_is_enforced():
    client = make_client(max_tokens=8)
    response = client.post(
        "/v1/chat/completions",
        json={"messages": [], "max_tokens": 9},
    )

    assert response.status_code == 400
    assert "server limit" in response.json()["detail"]


def test_per_ip_rate_limit_is_enforced():
    client = make_client(requests_per_minute=1)
    payload = {"messages": [{"role": "user", "content": "Hello"}]}

    first = client.post("/v1/chat/completions", json=payload)
    second = client.post("/v1/chat/completions", json=payload)

    assert first.status_code == 200
    assert second.status_code == 429
    assert second.headers["retry-after"] == "60"


def test_non_chat_routes_are_not_rate_limited():
    client = make_client(requests_per_minute=1)

    first = client.get("/health")
    second = client.get("/health")

    assert first.status_code == 200
    assert second.status_code == 200
