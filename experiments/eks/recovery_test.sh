#!/usr/bin/env bash

# Measure recovery of the single-replica Qwen deployment on EKS.
# Run this script with bash, not with source.

cd "$(git rev-parse --show-toplevel)" || exit 1

NS="modelops"
DEPLOY="qwen-vllm"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="results/eks/recovery/$STAMP"

mkdir -p "$OUT"

fail() {
    echo "FAILED: $*" | tee -a "$OUT/result.txt"
    echo "Diagnostic files are in $OUT"
    exit 1
}

echo "Run started: $(date -Is)" | tee "$OUT/result.txt"
echo "Context: $(kubectl config current-context)" \
    | tee -a "$OUT/result.txt"

CONTEXT="$(kubectl config current-context)"
case "$CONTEXT" in
    *modelops-gpu*) ;;
    *) fail "Unexpected Kubernetes context; refusing to restart a pod." ;;
esac

kubectl get deployment "$DEPLOY" -n "$NS" \
    -o yaml > "$OUT/deployment-before.yaml" \
    || fail "Cannot save the deployment configuration."

kubectl get pods -n "$NS" -l app=qwen-vllm -o wide \
    > "$OUT/pods-before.txt" \
    || fail "Cannot capture the initial pods."

READY="$(kubectl get deployment "$DEPLOY" -n "$NS" \
    -o jsonpath='{.status.readyReplicas}')"

[ "$READY" = "1" ] \
    || fail "Qwen must have exactly one ready replica before testing."

POD="$(kubectl get pods -n "$NS" -l app=qwen-vllm \
    -o jsonpath='{.items[0].metadata.name}')"

[ -n "$POD" ] || fail "Could not identify the Qwen pod."

echo "Initial pod: $POD" | tee -a "$OUT/result.txt"
date -Is > "$OUT/recovery-start.txt"
START="$(date +%s)"

echo "Deleting the Qwen pod to measure recovery..."
kubectl delete pod "$POD" -n "$NS" --wait=false \
    || fail "Could not request pod deletion."

if kubectl rollout status "deployment/$DEPLOY" \
    -n "$NS" --timeout=600s \
    > "$OUT/rollout-status.txt" 2>&1; then
    cat "$OUT/rollout-status.txt"
else
    cat "$OUT/rollout-status.txt"
    kubectl get pods -n "$NS" -l app=qwen-vllm -o wide \
        > "$OUT/pods-after.txt"
    kubectl describe deployment "$DEPLOY" -n "$NS" \
        > "$OUT/deployment-diagnostics.txt"
    fail "Deployment did not recover within 600 seconds."
fi

END="$(date +%s)"
ELAPSED=$((END - START))

echo "Recovery duration: $ELAPSED seconds" \
    | tee -a "$OUT/result.txt"
echo "Recovery completed: $(date -Is)" \
    | tee -a "$OUT/result.txt"

kubectl get pods -n "$NS" -l app=qwen-vllm -o wide \
    > "$OUT/pods-after.txt"

kubectl get deployment "$DEPLOY" -n "$NS" \
    -o yaml > "$OUT/deployment-after.yaml"

# Verify a real completion through the internal Kubernetes Service.
kubectl delete pod qwen-recovery-check -n "$NS" \
    --ignore-not-found=true --wait=true

kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: qwen-recovery-check
  namespace: modelops
spec:
  restartPolicy: Never
  containers:
    - name: api-check
      image: curlimages/curl:8.12.1
      command: ["/bin/sh", "-c"]
      args:
        - |
          curl -fsS --max-time 90 \
            http://qwen-vllm:8000/v1/chat/completions \
            -H 'Content-Type: application/json' \
            -d '{
              "model": "Qwen/Qwen2.5-1.5B-Instruct",
              "messages": [{
                "role": "user",
                "content": "Reply with exactly: EKS recovery test passed."
              }],
              "temperature": 0,
              "max_tokens": 24,
              "stream": false
            }' > /tmp/response.json || exit 1
          cat /tmp/response.json
          grep -q '"object":"chat.completion"' /tmp/response.json \
            || exit 1
          echo
          echo "INFERENCE_TEST=PASS"
      resources:
        requests:
          cpu: 50m
          memory: 32Mi
        limits:
          cpu: 250m
          memory: 64Mi
YAML

[ "$?" -eq 0 ] || fail "Could not create the inference check pod."

if kubectl wait -n "$NS" \
    --for=jsonpath='{.status.phase}'=Succeeded \
    pod/qwen-recovery-check --timeout=150s; then
    kubectl logs qwen-recovery-check -n "$NS" \
        > "$OUT/inference-test.txt" 2>&1
    cat "$OUT/inference-test.txt"
else
    kubectl logs qwen-recovery-check -n "$NS" \
        > "$OUT/inference-test.txt" 2>&1
    kubectl describe pod qwen-recovery-check -n "$NS" \
        > "$OUT/inference-diagnostics.txt"
    kubectl delete pod qwen-recovery-check -n "$NS" \
        --wait=true
    fail "Post-recovery inference test failed."
fi

grep -q 'INFERENCE_TEST=PASS' "$OUT/inference-test.txt" \
    || fail "Inference pod completed without a confirmed API response."

kubectl delete pod qwen-recovery-check -n "$NS" --wait=true

echo "RECOVERY_TEST=PASS" | tee -a "$OUT/result.txt"
echo "INFERENCE_TEST=PASS" | tee -a "$OUT/result.txt"
echo "Results saved in $OUT"
