# ModelOps LLM API

FastAPI gateway between the ModelOps chat application and vLLM.

## Endpoints

- `GET /health`: process health
- `GET /ready`: checks connectivity to vLLM
- `GET /v1/models`: proxies model discovery
- `POST /v1/chat/completions`: proxies OpenAI-compatible chat requests,
  including server-sent event streaming

## Configuration

- `VLLM_BASE_URL`: defaults to
  `http://qwen-vllm.modelops.svc.cluster.local:8000`
- `DEFAULT_MODEL`: defaults to `Qwen/Qwen2.5-1.5B-Instruct`
- `REQUEST_TIMEOUT_SECONDS`: defaults to `120`

## Run locally

Install `requirements-dev.txt`, then run:

    uvicorn app.main:app --host 127.0.0.1 --port 8000

Run automated tests from this directory:

    pytest -q

The backend is not deployed by this source-code step.
The Kubernetes deployment, internal Service, image repository and
Nginx proxy integration must be managed through the existing Terraform
deployment workflow before the public UI can use this backend.
