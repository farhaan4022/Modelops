# EKS Observability

## GPU metrics

DCGM Exporter runs in the gpu-monitoring namespace
and exposes Prometheus metrics on port 9400 at /metrics.

The exporter monitors the NVIDIA L4 GPU used by
the Qwen vLLM inference workload.

## Important metrics

- DCGM_FI_DEV_GPU_UTIL: GPU utilization percentage
- DCGM_FI_DEV_FB_USED: GPU framebuffer memory used, MiB
- DCGM_FI_DEV_GPU_TEMP: GPU temperature, Celsius

## Verify exporter

kubectl get daemonset,pods,services -n gpu-monitoring

kubectl logs -n gpu-monitoring \
  -l app.kubernetes.io/name=dcgm-exporter --tail=80

## Access metrics locally

kubectl port-forward --address 127.0.0.1 \
  -n gpu-monitoring service/dcgm-exporter 19400:9400

In another terminal:

curl -fsS http://127.0.0.1:19400/metrics

## Capacity constraint

The current EKS GPU node group has a maximum
of one NVIDIA L4 GPU node. Monitoring workloads
must not request GPU resources.

## Evidence

The timestamped results directory contains the
verified exporter logs and metrics scrape.
