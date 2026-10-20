# ModelOps — AWS Preflight Checklist

## Purpose

No GPU infrastructure may be provisioned until this checklist is completed.

The goal is to avoid:

- failed launches
- missing GPU quota
- wrong region selection
- unexpected pricing
- incompatible runtime assumptions
- unnecessary idle GPU cost
- orphaned AWS resources

This checklist is verification only.

It does not authorize provisioning.

---

# 1. AWS identity

Before provisioning, record:

AWS account alias:

TBD

AWS account ID:

TBD — do not commit publicly unless required

Active AWS CLI profile:

TBD

Authenticated identity confirmed with STS:

TBD

Expected IAM permissions available:

TBD

---

# 2. Region decision

Candidate region:

TBD

Final region:

TBD

The final region must be selected based on:

- g6.xlarge availability
- NVIDIA L4 availability
- On-Demand quota
- current price
- EKS support
- required AMI availability
- expected supporting-service cost

Do not choose a region only because it was used in another project.

Do not assume us-east-1 is automatically the final region.

---

# 3. GPU instance verification

Frozen initial EC2 target:

g6.xlarge

Expected accelerator:

1 × NVIDIA L4

Verify immediately before provisioning:

- [ ] g6.xlarge is offered in the selected region
- [ ] capacity is available in at least one suitable Availability Zone
- [ ] the instance specification still includes one NVIDIA L4
- [ ] host vCPU and RAM are confirmed
- [ ] current On-Demand hourly price is recorded
- [ ] no architecture change is required

If g6.xlarge cannot be launched:

Do not silently change instance type.

Record:

Problem:

Evidence:

Alternative considered:

Cost difference:

Technical difference:

Reason for change:

Approval decision:

---

# 4. GPU quota verification

Check the applicable EC2 accelerated/GPU On-Demand quota.

Required capacity for the initial target:

At least enough quota for one g6.xlarge.

Current quota:

TBD

Required quota:

TBD

Quota increase required:

TBD

Quota request ID:

TBD

Quota status:

TBD

Do not provision CPU infrastructure while waiting for GPU quota unless that work is independently required.

---

# 5. Pricing verification

The research snapshot from 2026-09-24 observed:

g6.xlarge in us-east-1:

USD 0.8048/hour

This is historical planning evidence only.

It is NOT the price to use automatically during implementation.

Immediately before provisioning record:

Selected region:

TBD

Current g6.xlarge On-Demand hourly price:

TBD

Price source:

TBD

Verification timestamp:

TBD

Estimated session length:

TBD

Estimated EC2 GPU compute cost:

TBD

Expected supporting-resource cost:

TBD

Maximum planned session cost:

TBD

---

# 6. AWS credits

Possible AWS credits are not treated as guaranteed.

Credit availability:

TBD

Credit balance:

TBD

Credit expiration:

TBD

Eligible services verified:

TBD

Important:

The project must remain affordable even if credits are unavailable.

Do not increase scope merely because credits exist.

---

# 7. AMI and NVIDIA runtime verification

Before EC2 creation identify the intended GPU-compatible AMI.

AMI family:

TBD

AMI ID:

TBD

AMI name:

TBD

AMI creation/publication date:

TBD

Operating system:

TBD

Expected NVIDIA driver:

TBD

Expected container runtime:

TBD

Reason selected:

TBD

Do not mix multiple driver-management approaches.

The EC2 baseline needs one clearly owned compatibility path.

---

# 8. vLLM image verification

Research candidate:

vllm/vllm-openai:v0.30.0-cu129

Before use verify:

- [ ] image still exists
- [ ] exact image digest is resolved
- [ ] vLLM version is confirmed
- [ ] expected CUDA runtime is confirmed
- [ ] Linux/NVIDIA requirements are compatible with selected AMI
- [ ] model loads successfully during compatibility testing

Final image:

TBD

Final digest:

TBD

---

# 9. Model verification

Frozen model:

Qwen/Qwen2.5-1.5B-Instruct

Frozen research revision:

989aa7980e4cf806f80c7fef2b1adb7bc71aa306

Before GPU execution verify:

- [ ] revision resolves successfully
- [ ] model files are accessible
- [ ] tokenizer resolves
- [ ] license information is retained
- [ ] no secret token is committed
- [ ] cache location is understood
- [ ] required storage is available

---

# 10. Storage planning

Initial planning envelope:

50–100 GiB

Final EC2 root volume:

TBD

Additional encrypted model/cache volume:

TBD

Encryption enabled:

TBD

Delete-on-termination behaviour:

TBD

Snapshot requirement:

TBD

Retained storage after session:

TBD

Do not retain large model caches indefinitely without a reason.

---

# 11. Network exposure

The vLLM API must not be publicly exposed by default merely for convenience.

Initial access method:

TBD

Security-group ingress:

TBD

SSH required:

TBD

SSM preferred/available:

TBD

Public IP required:

TBD

API authentication strategy:

TBD

A later demo client does not justify exposing an unauthenticated inference endpoint to the internet.

---

# 12. Terraform readiness

Before AWS creation verify:

Terraform version:

TBD

AWS provider version:

TBD

State backend:

TBD

State encryption:

TBD

State locking:

TBD

Project-specific AWS profile:

TBD

Terraform plan reviewed before apply:

TBD

No secret values may be stored in:

- Git
- committed tfvars
- Terraform outputs
- screenshots
- public evidence

---

# 13. Experiment readiness

Before starting the GPU:

- [ ] experiment is already defined
- [ ] commands are prepared
- [ ] expected outputs are known
- [ ] run ID is assigned
- [ ] evidence destination exists
- [ ] GPU sampling method is ready
- [ ] benchmark parameters are fixed
- [ ] cost ledger session ID is assigned
- [ ] teardown commands are prepared

Do not launch the GPU and then decide what to test.

---

# 14. Teardown readiness

Before provisioning verify that we know how to remove:

- EC2 GPU instance
- EBS volumes
- EBS snapshots
- Elastic IPs
- security groups created for the lab
- temporary IAM resources
- temporary S3 artifacts if applicable
- EKS cluster later
- EKS GPU node group later
- EKS CPU node group later
- load balancers later
- NAT gateways later

The destroy procedure must be known before the create procedure is executed.

---

# 15. Preflight gate

AWS provisioning is allowed only when these critical items are known:

- [ ] final region
- [ ] g6.xlarge availability
- [ ] GPU quota
- [ ] current hourly price
- [ ] maximum session budget
- [ ] selected AMI
- [ ] runtime compatibility plan
- [ ] vLLM image candidate
- [ ] model revision
- [ ] storage plan
- [ ] access method
- [ ] experiment run ID
- [ ] teardown method

Preflight status:

NOT READY

Change to READY only after every critical item above is verified.
