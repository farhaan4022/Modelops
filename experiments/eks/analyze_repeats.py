#!/usr/bin/env python3
import csv
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

root = Path(sys.argv[1])
files = sorted(root.glob("repeat*/*-summary.csv"))
report = []

def emit(line=""):
    print(line)
    report.append(line)

if not files:
    emit("ERROR: No repeat summary CSV files found.")
    sys.exit(1)

all_rows = []
groups = defaultdict(lambda: defaultdict(list))

emit("EKS BENCHMARK REPEATABILITY ANALYSIS")
emit(f"Evidence directory: {root}")
emit(f"Summary CSV files: {len(files)}")
emit("")

for path in files:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = reader.fieldnames or []

    emit(f"FILE: {path.relative_to(root)}")
    emit("COLUMNS: " + ", ".join(fields))

    if not rows:
        emit("WARNING: File contains no data rows.")
        emit("")
        continue

    for row in rows:
        emit("ROW: " + repr(row))
        row["_source"] = str(path.relative_to(root))
        all_rows.append(row)

        concurrency_key = next(
            (
                key for key in row
                if key and (
                    key.lower().replace("_", "").replace("-", "")
                    in ("concurrency", "concurrencylevel", "c")
                )
            ),
            None,
        )

        if concurrency_key is None:
            continue

        concurrency = str(row[concurrency_key]).strip()

        for key, value in row.items():
            if not key or key in (concurrency_key, "_source"):
                continue

            normalized = key.lower().replace("_", "").replace("-", "")
            if any(word in normalized for word in (
                "timestamp", "startedat", "finishedat",
                "requestid", "runid", "epoch"
            )):
                continue

            try:
                number = float(value)
            except (TypeError, ValueError):
                continue

            if math.isfinite(number):
                groups[concurrency][key].append(number)

    emit("")

emit("=== AGGREGATED NUMERIC METRICS BY CONCURRENCY ===")

if not groups:
    emit("No recognized concurrency column found.")
    emit("Use the printed CSV headers and rows to map the schema.")
else:
    for concurrency in sorted(
        groups,
        key=lambda value: (
            0, float(value)
        ) if value.replace(".", "", 1).isdigit() else (1, value)
    ):
        emit(f"CONCURRENCY = {concurrency}")

        for metric, values in sorted(groups[concurrency].items()):
            mean = statistics.mean(values)
            low = min(values)
            high = max(values)

            emit(
                f"  {metric}: mean={mean:.6g}, "
                f"min={low:.6g}, max={high:.6g}, "
                f"observations={len(values)}"
            )
        emit("")

emit("=== DATA COMPLETENESS ===")
emit(f"Rows read: {len(all_rows)}")
emit(f"Summary files discovered: {len(files)}")
emit("Review the rows and column names before drawing final conclusions.")

(root / "repeat-analysis.txt").write_text(
    "\n".join(report) + "\n", encoding="utf-8"
)

print(f"\nAnalysis report saved: {root / 'repeat-analysis.txt'}")
