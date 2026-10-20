# EC2 GPU Inference — Exploratory Baseline

## Environment

- Cloud: AWS EC2
- Instance: g6.xlarge
- GPU: NVIDIA L4
- Model: Qwen2.5-1.5B-Instruct
- Serving engine: vLLM v0.30.0
- Maximum model context: 2048 tokens
- Maximum scheduled sequences: 4
- GPU memory utilization setting: 0.70
- Maximum output length: 96 tokens
- Sampling temperature: 0

## Test design

A Python HTTP client issued streaming chat completion requests at
concurrency levels of 1, 4, 8, and 16.

Each level included 24 measured requests and one warm-up request.
Six prompts were reused across requests.

Measurements were taken from the client.

## Results

| Concurrency | Success | Mean latency (s) | P95 latency (s) | Mean TTFT (s) | P95 TTFT (s) | Requests/s | Output tokens/s |
|---|---|---:|---:|---:|---:|---:|---:|
| 1 | 24/24 | 1.268 | 1.269 | 0.019 | 0.020 | 0.788 | 75.69 |
| 4 | 24/24 | 1.307 | 1.312 | 0.032 | 0.037 | 3.059 | 293.68 |
| 8 | 24/24 | 2.393 | 2.618 | 1.116 | 1.341 | 3.063 | 294.04 |
| 16 | 24/24 | 3.923 | 5.232 | 2.645 | 3.955 | 3.058 | 293.55 |

## Observations

1. All 96 measured requests completed successfully.
2. Aggregate throughput increased substantially from concurrency 1 to 4.
3. Aggregate throughput remained near 294 output tokens/s
   at concurrency levels 4, 8, and 16.
4. Client-observed TTFT increased sharply above concurrency 4.
5. The pattern is consistent with contention and request queueing
   around the configured maximum of four scheduled sequences.

## Limitations

- Small sample sizes, especially for tail-latency estimates.
- Reused prompts may benefit from prefix caching.
- Generated token counts differ between responses.
- Requests were not launched simultaneously across all workers.
- TTFT measures the first nonempty streamed content chunk and
  includes networking and queueing time.
- Only one measured run was performed per concurrency level.

These results are exploratory. They must not be treated as
production capacity guarantees or definitive evidence of
llm-d performance improvements.

## Next experiments

- Capture reproducible machine-readable measurements.
- Use controlled prompt and output lengths.
- Measure queueing and token generation latency separately.
- Repeat workloads and report run-to-run variation.
- Test overload behavior and recovery.
