# ModelOps — Experiment Run Record

Use one copy of this template for each important benchmark, failure, recovery, or scheduling experiment.

Do not overwrite previous run records.

Recommended filename format:

YYYYMMDD-HHMM_<run-id>_<short-description>.md

Example:

20261005-1430_ec2-c1-001_concurrency-1-baseline.md

---

# Run identity

Run ID:

Date:

Start time:

End time:

Operator:

Experiment:

Platform:

- [ ] EC2
- [ ] EKS

Run type:

- [ ] compatibility
- [ ] cold
- [ ] warm
- [ ] benchmark
- [ ] saturation
- [ ] failure
- [ ] recovery
- [ ] scheduling
- [ ] cost
- [ ] other

---

# Engineering loop

## Problem

What engineering question are we trying to answer?

TBD

## Baseline

What known configuration or previous result are we comparing against?

TBD

## Observation

What behaviour did we observe before making a change?

TBD

## Hypothesis

What do we believe explains the observation?

TBD

## Engineering change

What single bounded change was made?

Use:

None — baseline run

when no engineering change was made.

TBD

## Experiment

What controlled test was performed?

TBD

## Evidence

What files, commands, metrics or screenshots support the result?

TBD

## Measured result

Record measurements only.

Do not write unsupported conclusions.

TBD

---

# Infrastructure metadata

AWS region:

Availability Zone:

Instance type:

EC2 instance ID:

EKS cluster:

EKS node:

GPU node group:

Purchase model:

- [ ] On-Demand
- [ ] Spot
- [ ] Not applicable

---

# GPU metadata

GPU model:

GPU count:

GPU total memory:

NVIDIA driver:

CUDA version reported by nvidia-smi:

GPU compute capability:

---

# Runtime metadata

Operating system:

AMI ID:

Kernel:

Container runtime:

Container runtime version:

vLLM version:

vLLM image:

vLLM image digest:

Model:

Qwen/Qwen2.5-1.5B-Instruct

Model revision:

989aa7980e4cf806f80c7fef2b1adb7bc71aa306

Tensor parallel size:

1

Maximum model length:

Runtime arguments:

---

# Workload metadata

Prompt corpus / dataset:

Seed:

Input-token target:

Output-token target:

Concurrency:

Request count:

Benchmark duration:

Streaming:

- [ ] yes
- [ ] no

Cold or warm:

- [ ] cold
- [ ] warm

---

# Client measurements

TTFT p50:

TTFT p95:

TTFT p99:

TPOT p50:

TPOT p95:

TPOT p99:

End-to-end latency p50:

End-to-end latency p95:

End-to-end latency p99:

Requests/second:

Output tokens/second:

Total tokens/second:

Submitted requests:

Successful requests:

Failed requests:

Interrupted streams:

Error rate:

---

# GPU/runtime measurements

GPU utilization average:

GPU utilization peak:

GPU memory baseline:

GPU memory peak:

KV-cache utilization:

Running requests:

Waiting requests:

OOM events:

Other runtime observations:

---

# Lifecycle measurements

Container/process start time:

Model load duration:

API ready time:

Cold-start-to-ready duration:

Failure timestamp:

Recovery timestamp:

Recovery-to-ready duration:

First successful post-recovery request:

---

# EKS scheduling data

Complete only for EKS experiments.

Requested GPU:

nvidia.com/gpu:

GPU node taint:

Pod toleration:

Node selector / affinity:

Pod scheduling result:

- [ ] Running
- [ ] Pending
- [ ] Failed
- [ ] Not applicable

Scheduler reason:

Time from pod creation to scheduled:

Time from scheduled to inference ready:

---

# Cost data

Session ledger ID:

GPU billable runtime:

Hourly compute rate used:

Estimated EC2 compute cost:

Estimated EKS control-plane cost:

Estimated CPU-node cost:

Estimated GPU-node cost:

Estimated storage cost:

Estimated network / load-balancer cost:

Estimated total experiment-session cost:

Cost per 1,000 successful requests:

Cost per 1,000 generated tokens:

Only calculate normalized costs when the denominator is meaningful and recorded.

---

# Evidence files

Raw benchmark result:

GPU samples:

Runtime metadata:

Application logs:

Failure logs:

Kubernetes events:

Screenshots:

Charts:

Cost record:

Other:

---

# Commands used

Record the important commands needed to reproduce this run.

```text
TBD
Unexpected behaviour
Record unexpected behaviour even if the experiment technically succeeded.
TBD
Interpretation
What does the measured evidence support?
TBD
What does the evidence NOT prove?
TBD
Decision
Choose one:
- [ ] retain baseline
- [ ] investigate further
- [ ] engineering change justified
- [ ] engineering change rejected
- [ ] experiment must be repeated
- [ ] result accepted
- [ ] inconclusive
Reason:
TBD
Resume-use status
Can this run support a public resume/interview claim?
- [ ] yes
- [ ] no
- [ ] not yet
If yes, state the exact defensible claim:
TBD
Do not convert a one-off observation into a generalized performance claim.
