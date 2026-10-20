# ModelOps — Compatibility Manifest

## Purpose

This file records the exact hardware and software combination used for ModelOps.

GPU inference depends on compatibility between:

- AWS instance type
- GPU architecture
- operating system / AMI
- Linux kernel
- NVIDIA driver
- CUDA runtime exposed to vLLM
- vLLM container image
- vLLM image digest
- model
- model revision
- model-serving configuration

A successful deployment is not considered reproducible unless these values are recorded.

Do not replace a version silently.

If any component changes, record:

1. what changed
2. why it changed
3. what failed or motivated the change
4. the validation performed afterward

---

# Frozen workload

## Model

Repository:

Qwen/Qwen2.5-1.5B-Instruct

Revision:

989aa7980e4cf806f80c7fef2b1adb7bc71aa306

Model role:

Primary ModelOps inference workload

Training:

None

Fine-tuning:

None

Initial maximum context:

2048 tokens

---

# Inference engine

Engine:

vLLM

Initial researched release:

v0.30.0

Initial researched CUDA 12.9 image candidate:

vllm/vllm-openai:v0.30.0-cu129

Important:

The actual container must be pinned by digest before it becomes the validated ModelOps runtime.

Do not treat a mutable image tag as sufficient reproducibility evidence.

Validated image:

TBD

Validated image digest:

TBD

---

# EC2 hardware baseline

AWS region:

TBD — verify immediately before provisioning

Instance type:

g6.xlarge

GPU:

NVIDIA L4

GPU count:

1

vCPU:

4

Host memory:

16 GiB

Storage:

TBD

Purchase model:

On-Demand for initial reproducible experiments

---

# EC2 operating system

AMI ID:

TBD

AMI name:

TBD

Operating system:

TBD

Kernel:

TBD

Architecture:

x86_64

---

# NVIDIA runtime

GPU reported by nvidia-smi:

TBD

NVIDIA driver version:

TBD

CUDA version reported by nvidia-smi:

TBD

Container-visible CUDA runtime:

TBD

GPU total memory:

TBD

GPU compute capability:

TBD

---

# Container runtime

Runtime:

TBD

Runtime version:

TBD

NVIDIA container integration:

TBD

Validation status:

TBD

---

# vLLM runtime validation

vLLM version:

TBD

Container image:

TBD

Container digest:

TBD

API endpoint:

OpenAI-compatible vLLM API

Initial tensor parallel size:

1

Initial GPU count:

1

Initial max model length:

2048

Initial concurrency:

1

Initial GPU memory utilization setting:

TBD — retain vLLM default unless measurement justifies changing it

Additional runtime arguments:

TBD

---

# Model validation

Resolved model revision:

TBD

Tokenizer revision:

TBD

Model load successful:

TBD

Model loaded on GPU:

TBD

Basic completion request successful:

TBD

Streaming request successful:

TBD

Metrics endpoint available:

TBD

---

# EC2 compatibility gate

The EC2 compatibility gate passes only when all of the following are true:

- [ ] EC2 instance is confirmed to contain one NVIDIA L4 GPU
- [ ] nvidia-smi works without error
- [ ] NVIDIA driver version is recorded
- [ ] CUDA compatibility is recorded
- [ ] container runtime can access the GPU
- [ ] exact vLLM image digest is recorded
- [ ] exact Qwen model revision is recorded
- [ ] vLLM loads Qwen successfully
- [ ] OpenAI-compatible API responds successfully
- [ ] streaming inference works
- [ ] GPU utilization changes during inference
- [ ] GPU memory usage is recorded
- [ ] metrics required for later experiments are accessible
- [ ] complete startup command/configuration is retained
- [ ] no credentials or secrets are committed

No performance benchmark is considered valid before this gate passes.

---

# EKS compatibility record

This section remains intentionally incomplete until EC2 baseline work is finished.

EKS cluster version:

TBD

GPU node AMI:

TBD

GPU node instance type:

TBD

NVIDIA driver:

TBD

NVIDIA device plugin version:

TBD

DCGM Exporter version:

TBD

Container runtime:

TBD

vLLM image digest:

TBD

Qwen revision:

989aa7980e4cf806f80c7fef2b1adb7bc71aa306

GPU Kubernetes resource:

nvidia.com/gpu

Expected GPU request:

1

GPU node taint:

TBD

Serving-pod toleration:

TBD

Serving-pod node selection:

TBD

---

# Change log

## Entry template

Date:

Component changed:

Previous value:

New value:

Reason:

Observed problem:

Hypothesis:

Validation performed:

Result:

Evidence location:

---

Do not populate a change entry merely because a newer version exists.

A version change requires an engineering reason.
