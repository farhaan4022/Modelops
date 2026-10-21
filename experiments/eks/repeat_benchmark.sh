#!/usr/bin/env bash

# Deliberately avoid set -e, set -u and pipefail.
# Run as a child process so failures do not exit the terminal shell.

cd "$HOME/projects/modelops" || {
    echo "ERROR: Cannot access the ModelOps repository."
    exit 1
}

if ! kubectl config current-context; then
    echo "ERROR: Kubernetes context is unavailable."
    exit 1
fi

STAMP=$(date -u +%Y%m%dT%H%M%SZ | tr "TZ" "tz")
OUT="results/eks/repeats/$STAMP"
CM="modelops-benchmark-script-$STAMP"
POD="modelops-benchmark-client-$STAMP"

CM_CREATED=0
POD_CREATED=0
FINAL_RC=0

mkdir -p "$OUT" || {
    echo "ERROR: Cannot create evidence directory."
    exit 1
}

cleanup() {
    echo
    echo "=== CLEANUP TEMPORARY RESOURCES ==="

    if [ "$POD_CREATED" -eq 1 ]; then
        kubectl delete pod "$POD" -n modelops \
            --wait=true --timeout=90s \
            > "$OUT/pod-cleanup.log" 2>&1
        CLEAN_RC=$?
        cat "$OUT/pod-cleanup.log"

        if [ "$CLEAN_RC" -ne 0 ]; then
            echo "WARNING: Check pod cleanup manually."
        fi
    fi

    if [ "$CM_CREATED" -eq 1 ]; then
        kubectl delete configmap "$CM" -n modelops \
            > "$OUT/configmap-cleanup.log" 2>&1
        CLEAN_RC=$?
        cat "$OUT/configmap-cleanup.log"

        if [ "$CLEAN_RC" -ne 0 ]; then
            echo "WARNING: Check ConfigMap cleanup manually."
        fi
    fi

    echo "Evidence retained at: $OUT"
}

trap cleanup EXIT

echo "=== 1. VERIFY REPOSITORY AND QWEN ==="
echo "Commit: $(git rev-parse HEAD 2>&1)"
echo "Evidence: $OUT"

git status -sb > "$OUT/git-status-before.txt" 2>&1

kubectl rollout status deployment/qwen-vllm \
    -n modelops --timeout=90s \
    > "$OUT/qwen-rollout-before.txt" 2>&1

RC=$?
cat "$OUT/qwen-rollout-before.txt"

if [ "$RC" -ne 0 ]; then
    echo "ERROR: Qwen is not confirmed healthy. Stopping."
    exit 1
fi

kubectl get deployment qwen-vllm -n modelops -o yaml \
    > "$OUT/qwen-deployment.yaml" 2>&1

if [ "$?" -ne 0 ]; then
    echo "ERROR: Could not capture Qwen configuration."
    exit 1
fi

git rev-parse HEAD > "$OUT/source-commit.txt"

echo
echo "=== 2. PREPARE BENCHMARK CLIENT CONFIGURATION ==="

kubectl create configmap "$CM" \
    --from-file=benchmark.py=experiments/ec2/benchmark.py \
    -n modelops \
    --dry-run=client -o yaml \
    > "$OUT/benchmark-script-configmap.yaml" \
    2> "$OUT/configmap-create-error.log"

RC=$?

if [ "$RC" -ne 0 ]; then
    cat "$OUT/configmap-create-error.log"
    echo "ERROR: Could not prepare benchmark ConfigMap."
    exit 1
fi

kubectl apply -f "$OUT/benchmark-script-configmap.yaml" \
    > "$OUT/configmap-apply.log" 2>&1

RC=$?
cat "$OUT/configmap-apply.log"

if [ "$RC" -ne 0 ]; then
    echo "ERROR: ConfigMap creation failed."
    exit 1
fi

CM_CREATED=1

echo
echo "=== 3. CREATE CPU-ONLY BENCHMARK POD ==="

cat > "$OUT/benchmark-client-pod.yaml" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $POD
  namespace: modelops
  labels:
    app: modelops-benchmark-client
spec:
  restartPolicy: Never
  containers:
    - name: benchmark
      image: python:3.12-slim
      imagePullPolicy: IfNotPresent
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: "1"
          memory: 512Mi
      volumeMounts:
        - name: benchmark-script
          mountPath: /bench
          readOnly: true
        - name: benchmark-results
          mountPath: /results
  volumes:
    - name: benchmark-script
      configMap:
        name: $CM
    - name: benchmark-results
      emptyDir: {}
EOF

kubectl apply -f "$OUT/benchmark-client-pod.yaml" \
    > "$OUT/pod-create.log" 2>&1

RC=$?
cat "$OUT/pod-create.log"

if [ "$RC" -ne 0 ]; then
    echo "ERROR: Benchmark pod creation failed."
    exit 1
fi

POD_CREATED=1

kubectl wait -n modelops \
    --for=condition=Ready "pod/$POD" \
    --timeout=180s \
    > "$OUT/pod-ready.log" 2>&1

RC=$?
cat "$OUT/pod-ready.log"

if [ "$RC" -ne 0 ]; then
    kubectl describe pod "$POD" -n modelops \
        > "$OUT/pod-diagnostics.txt" 2>&1
    cat "$OUT/pod-diagnostics.txt"
    echo "ERROR: Benchmark pod did not become ready."
    exit 1
fi

echo
echo "=== 4. VALIDATE BENCHMARK ARGUMENTS ==="

kubectl exec -n modelops "$POD" -- \
    python /bench/benchmark.py --help \
    > "$OUT/benchmark-help.txt" 2>&1

RC=$?
cat "$OUT/benchmark-help.txt"

if [ "$RC" -ne 0 ]; then
    echo "ERROR: Could not inspect benchmark CLI."
    exit 1
fi

for ARG in --url --concurrency --requests --max-tokens --output; do
    if ! grep -q -- "$ARG" "$OUT/benchmark-help.txt"; then
        echo "ERROR: Expected argument $ARG is not supported."
        echo "No benchmark run was started."
        exit 1
    fi
done

echo "Benchmark CLI validation: PASS"

echo
echo "=== 5. RUN THREE BENCHMARK REPETITIONS ==="
echo "Concurrency: 1, 4, 8, 16"
echo "Requests per concurrency: 24"
echo "Maximum generated tokens: 96"
echo "GPU requests from benchmark client: 0"

kubectl exec -n modelops "$POD" -- sh -c '
    python /bench/benchmark.py \
        --url http://qwen-vllm.modelops.svc.cluster.local:8000 \
        --concurrency 1 4 8 16 \
        --requests 24 \
        --max-tokens 96 \
        --output /results/repeat1 &&
    python /bench/benchmark.py \
        --url http://qwen-vllm.modelops.svc.cluster.local:8000 \
        --concurrency 1 4 8 16 \
        --requests 24 \
        --max-tokens 96 \
        --output /results/repeat2 &&
    python /bench/benchmark.py \
        --url http://qwen-vllm.modelops.svc.cluster.local:8000 \
        --concurrency 1 4 8 16 \
        --requests 24 \
        --max-tokens 96 \
        --output /results/repeat3
' > "$OUT/benchmark-run.log" 2>&1

RUN_RC=$?

cat "$OUT/benchmark-run.log"
echo "$RUN_RC" > "$OUT/benchmark-exit-code.txt"

if [ "$RUN_RC" -ne 0 ]; then
    echo "WARNING: At least one benchmark command failed."
    echo "Will preserve any partial results."
    FINAL_RC=1
fi

echo
echo "=== 6. COPY RESULTS FROM THE POD ==="

kubectl exec -n modelops "$POD" -- \
    sh -c 'find /results -type f -name "*.csv" -print' \
    > "$OUT/remote-files.txt" 2> "$OUT/file-list-error.log"

RC=$?

if [ "$RC" -ne 0 ]; then
    cat "$OUT/file-list-error.log"
    FINAL_RC=1
else
    while IFS= read -r REMOTE; do
        [ -n "$REMOTE" ] || continue

        RELATIVE="${REMOTE#/results/}"
        DEST="$OUT/$RELATIVE"

        mkdir -p "$(dirname "$DEST")"

        kubectl exec -n modelops "$POD" -- \
            cat "$REMOTE" > "$DEST" 2> "$OUT/copy-error.log"

        RC=$?

        if [ "$RC" -eq 0 ]; then
            echo "Saved: $DEST"
        else
            cat "$OUT/copy-error.log"
            rm -f "$DEST"
            FINAL_RC=1
        fi
    done < "$OUT/remote-files.txt"
fi

CSV_COUNT=$(find "$OUT" -type f -name '*.csv' | wc -l)
echo "CSV files copied: $CSV_COUNT" | tee "$OUT/result-count.txt"

if [ "$CSV_COUNT" -lt 9 ]; then
    echo "WARNING: Expected at least nine CSV files from three runs."
    FINAL_RC=1
fi

if [ "$RUN_RC" -eq 0 ] && [ "$CSV_COUNT" -ge 9 ]; then
    echo "BENCHMARK_STATUS=PASS" | tee "$OUT/status.txt"
else
    echo "BENCHMARK_STATUS=INCOMPLETE_OR_FAILED" \
        | tee "$OUT/status.txt"
fi

echo
echo "=== 7. VERIFY QWEN AND MONITORING ==="

kubectl get deployment qwen-vllm -n modelops \
    > "$OUT/qwen-deployment-after.txt" 2>&1
cat "$OUT/qwen-deployment-after.txt"

kubectl get pods -n gpu-monitoring \
    > "$OUT/monitoring-pods-after.txt" 2>&1
cat "$OUT/monitoring-pods-after.txt"

kubectl rollout status deployment/qwen-vllm \
    -n modelops --timeout=90s \
    > "$OUT/qwen-rollout-after.txt" 2>&1

RC=$?
cat "$OUT/qwen-rollout-after.txt"

if [ "$RC" -ne 0 ]; then
    FINAL_RC=1
fi

echo
echo "=== 8. FINAL REPOSITORY STATUS ==="

git status -sb > "$OUT/git-status-after.txt" 2>&1
cat "$OUT/git-status-after.txt"

echo
echo "=== BENCHMARK PHASE FINISHED ==="
echo "Exit status: $FINAL_RC"
echo "Evidence directory: $OUT"
echo "No Git commit or push performed."

exit "$FINAL_RC"
