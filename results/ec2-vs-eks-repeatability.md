# EC2–EKS Inference Benchmark: Repeatability Analysis

## Test setup

- Model: Qwen/Qwen2.5-1.5B-Instruct
- Inference engine: vLLM
- GPU allocation: one NVIDIA L4 GPU node; no additional GPU node
- Client: CPU-only pod inside the EKS cluster
- Repetitions: 3
- Requests per concurrency level per repetition: 24
- Maximum output tokens: 96
- Concurrency levels: 1, 4, 8 and 16
- Total EKS requests: 288
- Successful EKS requests: 288
- Failed EKS requests: 0

## Repeated EKS results

| Concurrency | Success per run | Mean throughput (tok/s) | Throughput range | Mean TTFT (s) | Mean P95 TTFT (s) | Mean P95 latency (s) | Peak waiting |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 24/24 | 74.800 | 74.695–74.914 | 0.0213 | 0.0240 | 1.2860 | 0.0 |
| 4 | 24/24 | 289.363 | 288.999–289.687 | 0.0363 | 0.0440 | 1.3343 | 0.0 |
| 8 | 24/24 | 289.935 | 289.727–290.099 | 1.1340 | 1.3657 | 2.6587 | 4.0 |
| 16 | 24/24 | 289.544 | 289.226–289.741 | 2.6843 | 4.0100 | 5.3037 | 12.0 |

## Comparison with the recorded EC2 baseline

| Concurrency | EC2 throughput (tok/s) | EKS repeated mean (tok/s) | EKS difference vs EC2 | EC2 mean TTFT (s) | EKS repeated mean TTFT (s) |
|---:|---:|---:|---:|---:|---:|
| 1 | 75.599 | 74.800 | -1.06% | 0.021 | 0.0213 |
| 4 | 292.628 | 289.363 | -1.12% | 0.036 | 0.0363 |
| 8 | 292.890 | 289.935 | -1.01% | 1.124 | 1.1340 |
| 16 | 292.421 | 289.544 | -0.98% | 2.660 | 2.6843 |

## Engineering interpretation

- All 288 requests in the three EKS repetitions succeeded.
- Throughput is repeatable across the three runs at each tested concurrency.
- Throughput reaches approximately 289–290 tokens/s from concurrency 4 onward.
- Mean time to first token and P95 latency rise at concurrency 8 and 16, while throughput remains nearly flat.
- Concurrency 4 is a promising operating point for further testing because it achieves near-maximum measured throughput without the observed waiting queue. It is not yet a validated production optimum.

## Comparison limitations

The EC2 figures come from the existing single-run comparison report; the EKS figures here are means from three repetitions. The existing report records differences in client and warm-up conditions for the earlier EKS run. Therefore, these figures are descriptive rather than a controlled, paired EC2-versus-EKS experiment. A strict platform comparison requires matching client placement, warm-up, request workload, model revision and measurement procedure.

These results describe the tested model, one-GPU configuration and workload. They are not a production capacity guarantee.

Evidence source: `results/eks/repeats/20261021t06061792562776z`
