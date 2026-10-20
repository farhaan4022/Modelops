# ModelOps — Experiment Plan

## Purpose

This document defines the experiment conditions before GPU infrastructure is created.

The project follows:

Problem
→ baseline
→ observation
→ hypothesis
→ engineering change
→ experiment
→ evidence
→ measured result

Experiments must not be redesigned after seeing results merely to produce better numbers.

Unexpected, degraded and failed runs are valid evidence.

---

# Experimental constants

Unless the specific experiment says otherwise, keep these constant.

Model:

Qwen/Qwen2.5-1.5B-Instruct

Model revision:

989aa7980e4cf806f80c7fef2b1adb7bc71aa306

Inference engine:

vLLM

GPU baseline:

1 × NVIDIA L4

EC2 baseline:

g6.xlarge

Initial maximum context:

2048 tokens

Tensor parallel size:

1

Model training:

None

Fine-tuning:

None

Quantization:

None initially

Reason:

The first baseline should measure a straightforward pinned Qwen/vLLM/L4 stack before introducing additional variables.

---

# Benchmark dimensions

## Input token targets

- 128
- 512
- 2048

## Output token targets

- 64
- 128
- 256

## Concurrency

- 1
- 2
- 4
- 8
- 16

## Run state

- cold
- warm

## Repetition requirement

Each comparable condition should be executed at least three times.

Do not compare runs that differ in undocumented ways.

---

# Experiment 0 — Compatibility validation

## Problem

Provisioning a GPU does not prove that the complete inference stack is compatible.

## Baseline question

Can the selected L4 host, NVIDIA runtime, pinned vLLM image and pinned Qwen revision operate together reproducibly?

## Measurements

- GPU detected
- driver version
- CUDA compatibility
- GPU memory
- vLLM startup result
- model-load result
- model-load duration
- API readiness
- basic inference result
- streaming inference result
- GPU utilization during inference
- GPU memory during inference

## Success criterion

Real Qwen inference succeeds through the vLLM OpenAI-compatible API and the complete compatibility manifest is captured.

## Engineering-change rule

If this experiment fails, diagnose compatibility first.

Do not begin performance tuning.

---

# Experiment 1 — Single-request baseline

## Problem

We need a clean latency and GPU baseline before concurrency introduces queueing and batching effects.

## Configuration

Concurrency:

1

Input token targets:

- 128
- 512
- 2048

Output token targets:

- 64
- 128
- 256

Run modes:

- cold
- warm

## Measure

- TTFT
- TPOT
- end-to-end latency
- request success
- generated tokens
- GPU utilization
- GPU memory
- model readiness
- cold-start time

## Desired outcome

Produce a reproducible single-request reference dataset.

No optimization claim is expected from this experiment.

---

# Experiment 2 — Concurrency and saturation

## Problem

A single-GPU inference server may increase throughput through batching while also increasing queueing and tail latency as demand approaches or exceeds capacity.

## Concurrency sweep

- 1
- 2
- 4
- 8
- 16

## Workload controls

Use the same:

- image digest
- model revision
- instance type
- GPU
- benchmark seed/corpus
- prompt-size distribution
- output-size distribution
- runtime configuration

unless a documented engineering change is being evaluated.

## Measure

Client:

- TTFT
- TPOT
- p50 latency
- p95 latency
- p99 latency
- request throughput
- token throughput
- successful requests
- failed requests

Runtime:

- GPU utilization
- GPU memory
- KV-cache behaviour
- running requests
- waiting requests
- queue behaviour
- OOM events

## Observation sought

Identify where increasing concurrency stops producing useful throughput gains or begins producing unacceptable queueing, latency degradation, errors or memory pressure.

Do not assume that concurrency 16 will saturate the workload.

The experiment determines the saturation region.

---

# Experiment 3 — Engineering change after saturation

This experiment is intentionally not fully designed yet.

It may only be defined after Experiment 2 produces evidence.

Possible engineering changes include:

- concurrency bounding
- context bounding
- scheduler/runtime configuration
- GPU memory utilization configuration
- admission control

A change must not be introduced because it appears impressive.

Before changing anything, document:

Problem:

Baseline:

Observation:

Hypothesis:

Proposed change:

Expected measurable effect:

Then rerun a directly comparable workload.

---

# Experiment 4 — Cold start and recovery

## Problem

GPU inference services have significant startup behaviour because the runtime and model must become ready before serving traffic.

## Scenarios

### A. Cold start

Measure:

- process/container start
- model loading
- API readiness
- first successful inference

### B. Controlled vLLM process termination

During or immediately before a controlled workload:

1. record service state
2. terminate vLLM
3. record affected requests/streams
4. restart using the same configuration
5. measure time until readiness
6. execute validation inference

## Measure

- cold-start-to-ready duration
- model-load duration
- interrupted requests
- failed requests
- recovery-to-ready duration
- successful post-recovery request
- GPU memory before/after recovery

---

# Experiment 5 — EKS GPU scheduling

Do not execute until EC2 experiments are complete.

## Problem

Kubernetes introduces a GPU-resource and scheduling model that does not exist in standalone EC2 operation.

## Questions

- Is the L4 exposed correctly as a Kubernetes resource?
- Can a pod request exactly one GPU?
- Does node placement work as designed?
- What happens when GPU capacity is unavailable?
- Can we explain a GPU pod remaining Pending?
- How long does the platform take from scheduling to inference readiness?
- How does failure/recovery differ from the EC2 baseline?

## Required evidence

- node GPU capacity
- node GPU allocatable resource
- pod GPU request
- GPU node taint
- workload toleration
- correct placement
- successful Qwen inference
- intentionally Pending GPU pod
- scheduler event explaining why it is Pending
- corrected configuration/capacity
- successful subsequent scheduling

---

# Measurement definitions

## TTFT

Time from client request submission until the first generated token is received.

## TPOT

Time spent generating output tokens after the first token, normalized per generated output token according to the benchmark implementation.

Record the exact benchmark definition used.

## End-to-end latency

Time from request submission until the response completes.

## Throughput

Always state the denominator explicitly.

Examples:

- requests/second
- output tokens/second
- total tokens/second

Never use the word "throughput" without saying what was counted.

## Error rate

failed requests / submitted requests

Record the failure categories separately when possible.

---

# Experiment metadata required for every run

Every run must record:

- run ID
- timestamp
- platform
- region
- instance type
- GPU
- model
- model revision
- vLLM version
- container digest
- driver version
- context limit
- concurrency
- input-token target
- output-token target
- benchmark duration or request count
- seed/corpus identifier
- run type
- runtime arguments
- result-file location

---

# Evidence policy

Keep:

- raw results
- failed results
- benchmark configuration
- command used
- runtime metadata
- GPU samples
- useful logs
- charts produced from raw data

Never manually edit raw benchmark data to create cleaner results.

Processed summaries must remain traceable to the raw source files.

---

# Result language

Before measurement:

"planned"

After a single observation:

"observed in this run"

After repeated comparable runs:

"measured across repeated controlled runs"

Do not use:

"improved"

"reduced"

"increased"

"optimized"

"more efficient"

unless a valid baseline comparison supports the statement.

---

# Architecture-change rule

An architecture or runtime change requires:

1. observed problem
2. evidence
3. hypothesis
4. bounded change
5. comparable experiment
6. measured result

This rule applies even when a commonly recommended tool or configuration appears to be an obvious improvement.
