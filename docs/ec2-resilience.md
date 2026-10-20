# EC2 Inference Resilience Experiments

## Environment

- AWS EC2: g6.xlarge
- GPU: NVIDIA L4
- Model: Qwen2.5-1.5B-Instruct
- Inference engine: vLLM v0.30.0
- Container orchestration: Docker Compose
- Restart policy: unless-stopped
- Inference API: localhost port 8000

## Experiment 1: Request overload

The inference server was tested with 32 requests per
concurrency level.

| Concurrency | Successful | Mean TTFT | Peak waiting | Output tokens/s |
|---|---|---|---|---|
| 4 | 32/32 | 0.034 s | 0 | 293.928 |
| 16 | 32/32 | 2.964 s | 12 | 294.198 |
| 32 | 32/32 | 4.635 s | 28 | 292.696 |

Observations:

- No requests failed during the measured experiment.
- Running sequences were limited by the configured
  maximum of four scheduled sequences.
- Additional demand caused queue buildup and higher TTFT.
- Aggregate output throughput remained near 293-294 tokens/s.

## Experiment 2: Recovery after overload

Immediately after the overload experiment:

- The vLLM health endpoint responded successfully.
- Running requests: 0
- Waiting requests: 0
- Recovery test requests: 12/12 successful
- Single-request output throughput: 75.651 tokens/s
- Mean TTFT: 0.019 seconds

Normal performance was observed after the load ended.

Exact recovery time was not measured.

## Experiment 3: Docker-initiated termination

The Compose-managed inference container was terminated
using Docker's SIGKILL operation.

Observed:

- Container exited with code 137.
- Docker restart count remained at zero.
- Automatic recovery was not observed during the test.
- The service was restored using Docker Compose.
- The health endpoint and inference API worked afterward.

This is an operator-initiated termination and does not,
by itself, establish failure of automatic recovery from
an unexpected application crash.

## Experiment 4: Direct process termination

An attempt was made to simulate an application crash by
sending SIGKILL to the container's host process.

Observed:

- The process was visible from the EC2 host.
- A signal-zero permission check succeeded.
- Sending SIGKILL returned "Permission denied".
- The inference service remained healthy.
- The container restart count remained zero.

The exact security mechanism responsible for denying
SIGKILL was not established.

Therefore, automatic restart after a genuine unexpected
application crash remains unverified.

## Engineering conclusions

1. The service remained available under the tested
   request overload.
2. Request queueing increased latency without increasing
   aggregate throughput.
3. Performance returned to baseline after overload.
4. Manual inference-service restoration was successful.
5. Automatic crash recovery requires separate verification.

## Limitations

- Single GPU and single inference replica.
- Small experimental workloads.
- Repeated prompts and possible prefix-cache effects.
- No application-level crash recovery measurement.
- No host reboot or Docker daemon failure testing.

These results describe observed behavior in this EC2
environment, not production availability guarantees.
