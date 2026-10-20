# ModelOps — Phase 0 Design Freeze

## Project identity

ModelOps is a GPU / LLM inference operations project.

The engineering value is in:

- GPU-backed LLM inference
- NVIDIA GPU runtime compatibility
- vLLM serving behaviour
- latency and throughput measurement
- concurrency and saturation
- GPU utilization and GPU memory
- KV-cache and queue behaviour
- cold-start characteristics
- operational failure and recovery
- reproducible infrastructure
- EKS GPU scheduling
- GPU observability
- cost measurement and control

ModelOps is not:

- a model-training project
- a generic Kubernetes showcase
- primarily an application-development project

## Frozen inference stack

Model:

Qwen/Qwen2.5-1.5B-Instruct

Frozen model revision:

989aa7980e4cf806f80c7fef2b1adb7bc71aa306

Inference engine:

vLLM

Infrastructure progression:

1. AWS EC2 with an NVIDIA L4 GPU
2. AWS EKS with GPU node(s)

Initial EC2 target:

g6.xlarge

Initial maximum context:

2048 tokens

## Engineering method

Every substantial change follows:

Problem
→ baseline
→ observation
→ hypothesis
→ engineering change
→ experiment
→ evidence
→ measured result

Do not change architecture without evidence.

Do not add tools merely for appearance.

## Application boundary

The user-facing application must remain deliberately minimal.

A small chat or Q&A web interface may be added later only as a demonstration client for the OpenAI-compatible vLLM API.

That interface is not the engineering focus.

The project value remains in:

- GPU inference engineering
- performance
- saturation behaviour
- observability
- EKS GPU scheduling
- reliability
- recovery
- runtime compatibility
- cost

## Explicitly excluded from the core architecture

Do not add these unless a measured engineering requirement later justifies them:

- AWS Lambda
- Amazon SQS
- Amazon EventBridge
- external LLM APIs
- RAG pipelines
- vector databases
- embedding services
- agent frameworks
- event-driven application architectures
- KServe
- additional inference engines
- multi-model serving
- multi-GPU distributed inference
- application microservices
- CI/CD or GitOps solely for appearance

Qwen is self-hosted through vLLM.

No external AI API is required for the core project.

## Phase A — EC2 baseline

The first real GPU workload runs on one AWS EC2 NVIDIA L4 instance.

Objectives:

1. Prove GPU, driver, CUDA runtime, vLLM and Qwen compatibility.
2. Establish a reproducible single-GPU inference baseline.
3. Measure latency and throughput.
4. Measure GPU utilization and memory.
5. Determine saturation behaviour under increasing concurrency.
6. Measure cold-start behaviour.
7. Test vLLM process failure and recovery.
8. Record operating cost.

EKS work begins only after the EC2 baseline is understood.

## Phase B — EKS GPU operations

After the EC2 baseline is complete, reproduce the same workload on EKS GPU nodes.

EKS exists to investigate:

- NVIDIA GPU exposure to Kubernetes
- nvidia.com/gpu resource semantics
- GPU requests
- GPU node placement
- taints and tolerations
- Pending pods caused by unavailable GPU capacity
- startup and readiness behaviour
- GPU telemetry
- pod failure
- node failure
- recovery behaviour
- EC2 versus EKS operational differences
- Kubernetes GPU cost implications

EKS must not become a generic Kubernetes demonstration.

## Initial benchmark matrix

Input-token targets:

- 128
- 512
- 2048

Output-token targets:

- 64
- 128
- 256

Concurrency:

- 1
- 2
- 4
- 8
- 16

Run types:

- cold
- warm

Comparable experiments should be repeated at least three times using the same:

- model revision
- container image
- resources
- workload definition
- prompt corpus or seed
- benchmark configuration

Failed and degraded runs must be retained.

## Primary measurements

### Client-side

- Time To First Token (TTFT)
- Time Per Output Token (TPOT)
- end-to-end latency
- p50 latency
- p95 latency
- p99 latency
- request throughput
- token throughput
- successful requests
- failed requests
- interrupted streams

### GPU/runtime

- GPU utilization
- GPU memory used
- GPU memory available
- KV-cache behaviour
- running requests
- waiting requests
- queue behaviour
- OOM events

### Lifecycle

- model-load time
- cold-start-to-ready time
- process restart time
- recovery-to-ready time
- interrupted requests during failure
- EKS scheduling time
- pod Pending duration
- node-to-inference-ready time

### Cost

- GPU session duration
- EC2 compute cost
- EKS control-plane runtime
- GPU-node runtime
- supporting AWS resource cost
- normalized successful-inference cost

## Evidence rule

A successful model response is not enough.

Retain:

- exact software versions
- exact model revision
- exact container digest
- GPU information
- benchmark configuration
- raw benchmark results
- GPU measurements
- failed runs
- failure timelines
- recovery measurements
- cost records
- architecture decisions
- useful screenshots

Resume claims must come from measured evidence.

Do not claim an improvement before measuring it.

## GPU cost rule

GPU infrastructure is session-based.

Workflow:

1. prepare experiments locally
2. verify configuration locally
3. start GPU infrastructure
4. execute the prepared experiment
5. capture raw evidence
6. stop or destroy charge-generating resources
7. analyze results locally

Do not leave an L4 running while writing scripts, documentation, or deciding what to test.

Before provisioning, verify:

- AWS region
- g6.xlarge availability
- GPU quota
- current hourly price
- expected session duration
- maximum session cost
