# ModelOps — GPU Cost Guardrails

## Principle

GPU time is for execution, not preparation.

Most work must happen locally before a GPU instance starts.

Required workflow:

Prepare locally
→ verify experiment
→ start GPU session
→ run experiment
→ capture evidence
→ stop/destroy expensive resources
→ analyze locally

---

# Session budget

Every GPU session must have a unique session ID.

Recommended format:

gpu-YYYYMMDD-NNN

Example:

gpu-20261005-001

Before starting a session record:

Session ID:

TBD

Experiment run IDs:

TBD

AWS region:

TBD

Resource:

g6.xlarge

Purchase model:

On-Demand

Current hourly rate:

TBD

Planned duration:

TBD

Maximum duration:

TBD

Estimated compute cost:

TBD

Maximum session cost:

TBD

---

# Hard operating rule

Do not start an L4 session unless all of these are true:

- experiment commands are prepared
- expected benchmark configuration is documented
- run IDs exist
- evidence paths exist
- current price is known
- session budget is known
- teardown procedure is ready

---

# During-session rule

While GPU billing is active:

Do:

- runtime validation
- model loading
- inference
- benchmarking
- controlled failure testing
- GPU measurement
- evidence collection

Avoid:

- writing documentation
- editing README files
- researching unrelated errors
- redesigning architecture
- writing benchmark scripts from scratch
- deciding which metrics to collect
- experimenting without a defined question

If substantial debugging requires offline work:

stop the GPU where practical,
debug locally,
then start a new controlled session.

---

# Session timing

Record actual:

Start time UTC:

TBD

Stop time UTC:

TBD

Billable duration:

TBD

Expected duration:

TBD

Variance:

TBD

Reason for variance:

TBD

---

# Session stop conditions

End the GPU session when:

- the planned experiment is complete
- required evidence is captured
- an unresolved issue requires substantial offline investigation
- experiment conditions are invalid
- expected cost limit is approaching
- the session no longer produces useful engineering evidence

Do not keep the instance running "just in case."

---

# Cost categories

Track separately:

## EC2

- GPU instance runtime
- CPU instance runtime if any

## Storage

- EBS volumes
- snapshots
- retained model cache

## Network

- public IPv4 where charged
- data transfer
- NAT Gateway if later introduced
- load balancer if later introduced

## EKS

Later track:

- EKS control plane
- GPU node runtime
- CPU/system node runtime
- EBS
- load balancers
- NAT Gateway if used
- observability retention

Do not report only the GPU instance price as the full AWS experiment cost.

---

# Normalized cost metrics

Calculate only where useful.

Possible metrics:

USD / 1,000 successful requests

USD / 1,000 generated output tokens

USD / benchmark run

USD / successful experiment session

Every normalized metric must include:

- numerator definition
- denominator definition
- runtime window
- AWS resources included
- AWS resources excluded

---

# Budget alerts

AWS Budgets or billing alerts may be configured later.

They are alerts.

They are not hard spending caps.

Manual teardown discipline remains mandatory.

---

# No idle demonstration infrastructure

Do not retain a running GPU instance for:

- portfolio screenshots
- recruiter demos
- interview convenience
- GitHub demonstration
- keeping the API continuously online

A later demo may use a deliberately scheduled short session.

---

# EKS-specific guardrail

EKS is short-lived.

Do not create EKS until the EC2 baseline is complete.

Before creating EKS calculate:

EKS control-plane expected runtime:

TBD

GPU-node expected runtime:

TBD

CPU-node expected runtime:

TBD

Load-balancer expected runtime:

TBD

NAT Gateway expected runtime if applicable:

TBD

Expected total experiment cost:

TBD

Maximum allowed session cost:

TBD

---

# Post-session audit

After each GPU session check for remaining charge-generating resources.

EC2 instance:

TBD

EBS volume:

TBD

Elastic IP:

TBD

Snapshot:

TBD

Load balancer:

TBD

NAT Gateway:

TBD

EKS cluster:

TBD

EKS nodes:

TBD

Other:

TBD

Audit result:

TBD

---

# Project budget principle

The project must not be reduced into a superficial deployment merely to minimize GPU cost.

Cost control comes from:

- preparing locally
- bounded sessions
- repeatable scripts
- planned experiments
- rapid teardown
- avoiding unnecessary infrastructure
- measuring before expanding

We save money by eliminating idle and unjustified infrastructure, not by removing the engineering experiments that define ModelOps.
