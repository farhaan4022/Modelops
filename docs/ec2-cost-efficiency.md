# EC2 GPU Inference — Cost and Efficiency Analysis

## Environment

- AWS Region: us-east-1
- Instance: g6.xlarge (On-Demand Linux)
- GPU: NVIDIA L4
- Model: Qwen2.5-1.5B-Instruct
- Inference server: vLLM v0.30.0
- Root storage: 120 GiB gp3 EBS

## Pricing assumptions

| Resource | Unit price |
|---|---:|
| EC2 compute | $0.8048/hour |
| EBS gp3 storage | $0.08/GB-month |
| Public IPv4 | $0.005/hour |

Assume a 30-day month (720 hours).

120 GB EBS storage:
120 * $0.08 = $9.60/month.

Running instance compute plus one public IPv4:
$0.8048 + $0.005 = $0.8098/hour.

When the EC2 instance is stopped, instance compute
charges stop, but provisioned EBS storage remains billable.

These are estimated list-price costs, not actual AWS bills.

## Reproducible benchmark results

Source:
results/ec2/20261020T093436Z-summary.csv

| Concurrency | Output tokens/sec | Mean TTFT |
|---|---:|---:|
| 1 | 75.599 | 0.021 s |
| 4 | 292.628 | 0.036 s |
| 8 | 292.890 | 1.124 s |
| 16 | 292.421 | 2.660 s |

All 96 measured requests completed successfully.

## Compute cost per million generated tokens

Formula:

Cost per 1M output tokens =
(EC2 hourly cost * 1,000,000) /
(output tokens per second * 3600)

| Concurrency | Estimated compute cost / 1M output tokens |
|---|---:|
| 1 | $2.96 |
| 4 | $0.76 |
| 8 | $0.76 |
| 16 | $0.76 |

These figures are theoretical extrapolations from short
benchmarks, assuming sustained measured throughput.

They exclude idle time, EBS, IPv4, data transfer, taxes,
model initialization, and other AWS service charges.

## Performance versus cost

At concurrency 4, aggregate throughput reached about
293 output tokens/second.

Increasing concurrency to 8 or 16 did not materially
improve output throughput. It increased time to first
token because additional requests waited for capacity.

Therefore, higher concurrency did not improve estimated
compute cost per output token in this experiment.

## Operational cost considerations

- A running GPU instance incurs compute charges even
  when no inference requests are being processed.
- Stopping EC2 preserves the EBS-backed model cache
  while avoiding instance compute charges.
- EBS charges continue until the volume is deleted.
- A public IPv4 address may incur hourly charges
  while allocated.
- AWS billing and the project cost ledger should be
  used for actual spending totals.

## Limitations

- Single GPU and one vLLM replica.
- Short benchmark runs.
- No repeated-run confidence intervals.
- Reused prompt structures and possible prefix caching.
- No full utilization or monthly workload model.
- Actual billed spend has not been reconciled.

## Pricing references

- https://calculator.holori.com/aws/ec2/g6.xlarge
- https://aws.amazon.com/ebs/pricing/
- https://aws.amazon.com/vpc/pricing/
