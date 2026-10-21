# EC2 and EKS inference comparison

## Test setup

- Model: Qwen2.5-1.5B-Instruct
- Inference engine: vLLM
- GPU: NVIDIA L4
- Maximum output: 96 tokens
- Requests: 24 at each concurrency level
- Concurrency: 1, 4, 8 and 16
- Client: in-cluster Kubernetes pod for the EKS run
- EKS warm-up: five additional requests before the benchmark

## Results

| Concurrency | EC2 success | EKS success | EC2 tok/s | EKS tok/s | Difference | EC2 mean TTFT | EKS mean TTFT |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 24/24 | 24/24 | 75.599 | 75.362 | -0.31% | 0.021s | 0.021s |
| 4 | 24/24 | 24/24 | 292.628 | 292.488 | -0.05% | 0.036s | 0.034s |
| 8 | 24/24 | 24/24 | 292.890 | 292.700 | -0.06% | 1.124s | 1.123s |
| 16 | 24/24 | 24/24 | 292.421 | 292.184 | -0.08% | 2.660s | 2.660s |

## Observations

- All 96 measured requests succeeded in each run.
- Throughput was similar in the recorded EC2 and in-cluster EKS runs.
- Throughput levelled off at around 293 output tokens/s from concurrency 4.
- Queueing increased at concurrency 8 and 16.
- The earlier EKS run had different client and warm-up conditions.
- These are individual benchmark runs, not production capacity guarantees.
