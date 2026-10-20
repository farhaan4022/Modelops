# ModelOps — EC2 Inference Operations Runbook

## Infrastructure

- AWS Region: us-east-1
- EC2 instance type: g6.xlarge
- GPU: NVIDIA L4
- Operating system: Ubuntu 22.04 NVIDIA GPU AMI
- Provisioning: Terraform
- Remote access: AWS Systems Manager Session Manager
- Root storage: 120 GiB gp3 EBS

## Inference service

- Model: Qwen2.5-1.5B-Instruct
- Inference engine: vLLM v0.30.0
- Runtime: Docker Compose
- API: http://127.0.0.1:8000
- API exposure: EC2 localhost only
- Persistent model cache: /opt/modelops/hf-cache
- Compose configuration: /opt/modelops/deploy/compose.yaml

The version-controlled Compose source is:
deploy/ec2/compose.yaml

## Connect to the EC2 instance

From the local repository:

    cd ~/projects/modelops

    aws ssm start-session \
      --profile modelops \
      --region us-east-1 \
      --target "$(cd infra/ec2 && terraform output -raw gpu_instance_id)"

Inside the EC2 session:

    sudo -i

## Verify inference health

    docker compose -f /opt/modelops/deploy/compose.yaml ps

    curl -fsS http://127.0.0.1:8000/health

    nvidia-smi

## Start or restore inference

If the service has been deliberately stopped:

    docker compose -f /opt/modelops/deploy/compose.yaml \
      start inference

Allow time for Qwen to initialize.

If the container does not exist, the version-controlled
Compose configuration must first be installed at the
expected path on EC2. Then it can be created with:

    docker compose -f /opt/modelops/deploy/compose.yaml \
      up -d

The model cache is stored on EBS-backed storage so
previously downloaded model files can survive EC2 stops.

## Inspect service logs

    docker compose -f /opt/modelops/deploy/compose.yaml \
      logs --tail 100 inference

## Verify metrics

    curl -fsS http://127.0.0.1:8000/metrics

Important metrics include:

- vllm:num_requests_running
- vllm:num_requests_waiting
- vllm:kv_cache_usage_perc

## Benchmarking

Source code:

    experiments/ec2/benchmark.py

Version-controlled baseline results:

    results/ec2/20261020T093436Z-summary.csv

Overload results:

    results/ec2/overload/

Post-overload recovery results:

    results/ec2/recovery/

The benchmark requires access to the localhost inference API.

## Observed performance

In the recorded baseline:

- Maximum configured scheduled sequences: 4
- Throughput near saturation: approximately 293 output tokens/s
- Concurrency 16: peak waiting requests of 12
- Concurrency 32 overload: peak waiting requests of 28

Higher concurrency increased queueing and TTFT without
meaningfully improving aggregate throughput.

## Failure recovery

Manual restoration using Docker Compose was verified.

The configured restart policy is unless-stopped.

Automatic recovery after a genuine unexpected application
crash was not verified in the experiments.

Refer to:

    docs/ec2-resilience.md

Do not interpret an explicitly initiated Docker kill
as equivalent to an unexpected application crash.

## Cost controls

GPU instance compute charges accrue while EC2 is running,
including periods when the inference service is idle.

Stopping EC2 avoids ongoing instance compute charges.
Provisioned EBS storage continues to incur charges.

The EC2 instance should be stopped when no further
experiments are planned for the session.

See:

    docs/ec2-cost-efficiency.md

Do not run terraform destroy without an explicit decision
to remove the infrastructure and associated storage.

## Security

- No public inbound security-group rules are configured.
- The inference API is bound to 127.0.0.1.
- EC2 administration uses AWS Systems Manager.
- Terraform state and AWS credentials must not be committed.
- The AWS CLI profile used for this project is modelops.

## EKS handover

The EKS phase will reuse the same Qwen model and vLLM
serving configuration where practical.

EC2 benchmark measurements provide the baseline for
future Kubernetes and llm-d comparisons.

The lightweight web chat will be implemented on EKS,
not on the EC2 baseline instance.
