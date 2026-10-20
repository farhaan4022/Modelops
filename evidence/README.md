ModelOps Evidence
This directory contains evidence supporting ModelOps engineering claims.
The objective is not to collect screenshots for appearance.
Every retained artifact should answer an engineering question or support reproducibility.
Evidence categories
Recommended structure:
evidence/
├── architecture/
├── compatibility/
├── ec2-baseline/
├── saturation/
├── failures/
├── eks-scheduling/
├── telemetry/
├── cost/
└── run-records/
Create category directories only when they are actually needed.
Evidence hierarchy
Prefer evidence in this order:
1. raw machine-readable result
2. exact runtime metadata
3. command/configuration used
4. logs or Kubernetes events
5. derived chart/table
6. screenshot
A screenshot should supplement raw evidence, not replace it.
Raw-data rule
Never manually edit raw benchmark results to improve presentation.
If data requires cleaning or aggregation:
- preserve the raw source
- create a separate processed file
- document the transformation
- keep the result traceable to the source run ID
Run IDs
Every meaningful experiment should have a unique run ID.
Recommended format:
platform-workload-sequence
Examples:
ec2-c1-001
ec2-c4-001
ec2-c16-003
ec2-restart-001
eks-pending-001
eks-recovery-001
Use the same run ID across:
- run record
- benchmark output
- GPU samples
- logs
- screenshots
- cost ledger
- generated charts
Screenshot rule
Useful screenshots include:
- nvidia-smi proving the actual L4 GPU and driver
- successful vLLM model startup
- GPU utilization during inference
- Kubernetes GPU capacity and allocatable resources
- intentionally Pending GPU pod with scheduler reason
- corrected pod successfully scheduled
- telemetry showing a measured saturation or failure event
Avoid screenshots whose only evidence is:
- AWS console showing an instance exists
- Kubernetes dashboard showing a green pod
- chat UI showing the model answered a question
Those may be demo material but are weak engineering evidence.
Public-repository rule
Never store:
- AWS credentials
- access keys
- session tokens
- Hugging Face tokens
- private SSH keys
- secrets
- private IP information when unnecessary
- personally sensitive data
- account IDs when unnecessary
Sanitize logs and screenshots before publishing them.
Resume rule
A claim can be used only when:
- the underlying experiment exists
- the raw evidence is retained
- measurement conditions are known
- the result can be explained
- limitations are understood
No invented percentage improvements.
No production-scale availability claims from a temporary laboratory environment.
