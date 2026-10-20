#!/usr/bin/env python3

import concurrent.futures
import json
import math
import statistics
import time
import urllib.request

URL = "http://127.0.0.1:8000/v1/chat/completions"
MODEL = "Qwen/Qwen2.5-1.5B-Instruct"
CONCURRENCY_LEVELS = [1, 4, 8, 16]
REQUESTS_PER_LEVEL = 24
TIMEOUT_SECONDS = 120

PROMPTS = [
    "Describe GPU memory management during language model inference.",
    "Describe how continuous batching improves inference throughput.",
    "Describe why inference request queues form under heavy load.",
    "Describe the difference between latency and throughput in model serving.",
    "Describe how a Kubernetes GPU scheduler allocates accelerator resources.",
    "Describe the purpose of a KV cache in transformer inference.",
]

def percentile(values, fraction):
    values = sorted(values)
    position = max(0, math.ceil(len(values) * fraction) - 1)
    return values[position]

def send_request(index):
    payload = json.dumps({
        "model": MODEL,
        "messages": [{
            "role": "user",
            "content": PROMPTS[index % len(PROMPTS)]
        }],
        "max_tokens": 96,
        "temperature": 0,
        "stream": True,
        "stream_options": {"include_usage": True}
    }).encode()

    request = urllib.request.Request(
        URL,
        data=payload,
        headers={"Content-Type": "application/json"}
    )

    start = time.perf_counter()
    first_token = None
    output_tokens = 0

    try:
        with urllib.request.urlopen(
            request, timeout=TIMEOUT_SECONDS
        ) as response:
            for raw_line in response:
                line = raw_line.decode("utf-8").strip()

                if not line.startswith("data: "):
                    continue

                data = line[6:]
                if data == "[DONE]":
                    break

                event = json.loads(data)

                for choice in event.get("choices", []):
                    content = choice.get("delta", {}).get("content")
                    if content and first_token is None:
                        first_token = time.perf_counter() - start

                usage = event.get("usage")
                if usage:
                    output_tokens = usage.get(
                        "completion_tokens", output_tokens
                    )

        latency = time.perf_counter() - start

        if first_token is None:
            raise RuntimeError("No generated content received")

        return {
            "ok": True,
            "latency": latency,
            "ttft": first_token,
            "tokens": output_tokens
        }

    except Exception as error:
        return {
            "ok": False,
            "error": str(error),
            "latency": time.perf_counter() - start
        }

print("ModelOps - Streaming Inference Baseline")
print(f"Requests per level: {REQUESTS_PER_LEVEL}")
print(f"Maximum generated tokens: 96")
print()

for concurrency in CONCURRENCY_LEVELS:
    # Warm up before each measured group.
    warmup = send_request(0)
    if not warmup["ok"]:
        raise SystemExit(f"Warmup failed: {warmup['error']}")

    start = time.perf_counter()

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=concurrency
    ) as executor:
        results = list(executor.map(
            send_request,
            range(REQUESTS_PER_LEVEL)
        ))

    duration = time.perf_counter() - start
    successful = [r for r in results if r["ok"]]
    failures = [r for r in results if not r["ok"]]

    print(f"Concurrency: {concurrency}")
    print(f"  Successful: {len(successful)}/{REQUESTS_PER_LEVEL}")
    print(f"  Failures: {len(failures)}")

    if successful:
        latencies = [r["latency"] for r in successful]
        ttfts = [r["ttft"] for r in successful]
        tokens = sum(r["tokens"] for r in successful)

        print(f"  Mean latency: {statistics.mean(latencies):.3f} s")
        print(f"  P95 latency: {percentile(latencies, 0.95):.3f} s")
        print(f"  Mean TTFT: {statistics.mean(ttfts):.3f} s")
        print(f"  P95 TTFT: {percentile(ttfts, 0.95):.3f} s")
        print(f"  Requests/sec: {len(successful)/duration:.3f}")
        print(f"  Output tokens/sec: {tokens/duration:.2f}")

    for failure in failures[:3]:
        print(f"  Error: {failure['error']}")

    print()
