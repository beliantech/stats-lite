#!/usr/bin/env python3
"""Classify SMC temperature keys from Phase 0 load-attribution logs.

Plan: plans/2026-10-23-temp-menu-bar-metric.md

Reads the watch logs produced by tools/smc-probe/probe --watch:

  h1-baseline.log    one run (baseline)
  h1-cpu-load.log    one run (CPU load phase)
  h1-cool.log        one run (post-CPU recovery phase)
  h1-gpu-load.log    one run (GPU load phase)
  h1-gpu-cool.log    one run (post-GPU recovery phase)

A load log that contains a '# phase=recovery' run is also accepted as the
recovery source when the matching cool log is absent.

Prints per-key baseline, CPU-round, and GPU-round means, deltas from
baseline, recovery deltas, and a classification:

  CPU-side   CPU-round mean rose at least 15 C and more than the GPU round
  GPU-side   GPU-round mean rose at least 15 C and more than the CPU round
  ambiguous  both rounds rose at least 15 C and the deltas differ by < 5 C
  neither    no round rose 15 C

Usage:
  python3 analyze_attribution.py <artifacts-dir>
"""

import os
import statistics
import sys

RISE_THRESHOLD = 15.0   # C, Phase 0 H1 falsification band: 15-25 C
AMBIGUITY_GAP = 5.0     # C, CPU-vs-GPU delta gap below which a key is ambiguous
FALLBACK_BAND = 5.0     # C, recovery must land within baseline + this


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def read_log(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read().splitlines()
    except OSError as error:
        fail(f"cannot read {path}: {error}")
    return []


def parse_runs(path):
    """Return [(label, {key: [value, ...]})] for each --watch run in a log."""
    runs = []
    label = None
    current = None
    for line in read_log(path):
        if line.startswith("# phase="):
            label = line.split("=", 1)[1]
            continue
        if line.startswith("# mode=watch"):
            if current is not None:
                runs.append(current)
            name = label if label is not None else f"run{len(runs) + 1}"
            current = (name, {})
            label = None
            continue
        if current is None or line.startswith("#"):
            continue
        for part in line.split()[1:]:
            if "=" not in part:
                continue
            key, value = part.split("=", 1)
            if value == "--":
                continue
            try:
                current[1].setdefault(key, []).append(float(value))
            except ValueError:
                continue
    if current is not None:
        runs.append(current)
    return runs


def stats(samples):
    return statistics.mean(samples), max(samples)


def fmt(value):
    if value is None:
        return "--"
    return f"{value:.1f}"


def load_run(path, phase=None):
    runs = parse_runs(path)
    if not runs:
        fail(f"no watch run in {path}")
    if phase is not None:
        for name, values in runs:
            if name == phase:
                return values
    return runs[0][1]


def recovery_run(cool_path, load_path):
    if os.path.exists(cool_path):
        return load_run(cool_path)
    return load_run(load_path, "recovery")


def classify(cpu_delta, gpu_delta):
    if cpu_delta is None or gpu_delta is None:
        return "incomplete"
    if cpu_delta >= RISE_THRESHOLD and gpu_delta >= RISE_THRESHOLD:
        if abs(cpu_delta - gpu_delta) < AMBIGUITY_GAP:
            return "ambiguous"
        return "CPU-side" if cpu_delta > gpu_delta else "GPU-side"
    if cpu_delta >= RISE_THRESHOLD:
        return "CPU-side"
    if gpu_delta >= RISE_THRESHOLD:
        return "GPU-side"
    return "neither"


def delta(base_mean, value):
    if base_mean is None or value is None:
        return None
    return value - base_mean


def build_rows(base_values, cpu_load, cpu_rec, gpu_load, gpu_rec):
    rows = []
    for key in sorted(set(base_values) | set(cpu_load) | set(gpu_load)):
        base_mean = stats(base_values[key])[0] if key in base_values else None
        cpu = stats(cpu_load[key]) if key in cpu_load else None
        gpu = stats(gpu_load[key]) if key in gpu_load else None
        crec = stats(cpu_rec[key]) if key in cpu_rec else None
        grec = stats(gpu_rec[key]) if key in gpu_rec else None
        cpu_delta = delta(base_mean, cpu[0] if cpu else None)
        gpu_delta = delta(base_mean, gpu[0] if gpu else None)
        rows.append({
            "key": key,
            "base": base_mean,
            "cpu": cpu[0] if cpu else None,
            "gpu": gpu[0] if gpu else None,
            "cpu_delta": cpu_delta,
            "gpu_delta": gpu_delta,
            "cpu_peak": delta(base_mean, cpu[1] if cpu else None),
            "gpu_peak": delta(base_mean, gpu[1] if gpu else None),
            "cpu_rec_delta": delta(base_mean, crec[0] if crec else None),
            "gpu_rec_delta": delta(base_mean, grec[0] if grec else None),
            "class": classify(cpu_delta, gpu_delta),
        })
    return rows


def print_table(rows):
    header = ("key", "baseline", "cpu-load", "gpu-load", "dCPU", "dGPU",
              "peakCPU", "peakGPU", "recCPU", "recGPU", "class")
    print("| " + " | ".join(header) + " |")
    print("|" + "|".join(["---"] * len(header)) + "|")
    ordered = sorted(rows, key=lambda row: -(row["cpu_delta"] or -999))
    for row in ordered:
        cells = (
            row["key"], fmt(row["base"]), fmt(row["cpu"]), fmt(row["gpu"]),
            fmt(row["cpu_delta"]), fmt(row["gpu_delta"]),
            fmt(row["cpu_peak"]), fmt(row["gpu_peak"]),
            fmt(row["cpu_rec_delta"]), fmt(row["gpu_rec_delta"]), row["class"],
        )
        print("| " + " | ".join(cells) + " |")


def print_summary(rows):
    cpu_side = [row for row in rows if row["class"] == "CPU-side"]
    gpu_side = [row for row in rows if row["class"] == "GPU-side"]
    ambiguous = [row for row in rows if row["class"] == "ambiguous"]
    in_band = [row for row in cpu_side
               if row["cpu_delta"] is not None
               and 15.0 <= row["cpu_delta"] <= 25.0]
    neither = len(rows) - len(cpu_side) - len(gpu_side) - len(ambiguous)
    print()
    print(f"# summary keys_total={len(rows)} cpu_side={len(cpu_side)} "
          f"gpu_side={len(gpu_side)} ambiguous={len(ambiguous)} neither={neither}")
    print(f"# cpu_side keys with delta in the 15-25 C band: {len(in_band)}")
    print("# H1 CPU-side candidates (top 12 by dCPU):")
    for row in sorted(cpu_side, key=lambda item: -(item["cpu_delta"] or 0))[:12]:
        print(f"  {row['key']} baseline={row['base']:.1f} "
              f"cpu={row['cpu']:.1f} (d={row['cpu_delta']:+.1f} "
              f"peak={row['cpu_peak']:+.1f} "
              f"recovery={row['cpu_rec_delta'] or 0:+.1f}) "
              f"gpu d={row['gpu_delta'] or 0:+.1f}")
    if gpu_side:
        print("# GPU-side candidates (top 12 by dGPU):")
        for row in sorted(gpu_side, key=lambda item: -(item["gpu_delta"] or 0))[:12]:
            print(f"  {row['key']} baseline={row['base']:.1f} "
                  f"gpu={row['gpu']:.1f} (d={row['gpu_delta']:+.1f} "
                  f"peak={row['gpu_peak']:+.1f} "
                  f"recovery={row['gpu_rec_delta'] or 0:+.1f}) "
                  f"cpu d={row['cpu_delta'] or 0:+.1f}")
    else:
        print("# GPU-side candidates: none (recorded per reviewer F3 sub-rule)")

    recovered = [row for row in in_band
                 if row["cpu_rec_delta"] is not None
                 and row["cpu_rec_delta"] <= FALLBACK_BAND]
    verdict = "GO" if in_band else "NO GO"
    print(f"# H1 verdict: {verdict} (band keys={len(in_band)}, "
          f"recovered-within-{FALLBACK_BAND:.0f}C={len(recovered)})")


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    base_dir = sys.argv[1]
    if not os.path.isdir(base_dir):
        fail(f"not a directory: {base_dir}")
    baseline_path = os.path.join(base_dir, "h1-baseline.log")
    cpu_path = os.path.join(base_dir, "h1-cpu-load.log")
    gpu_path = os.path.join(base_dir, "h1-gpu-load.log")

    baseline_runs = parse_runs(baseline_path)
    if not baseline_runs:
        fail(f"no watch run in {baseline_path}")
    cool_path = os.path.join(base_dir, "h1-cool.log")
    gpu_cool_path = os.path.join(base_dir, "h1-gpu-cool.log")
    cpu_load = load_run(cpu_path)
    cpu_rec = recovery_run(cool_path, cpu_path)
    gpu_load = load_run(gpu_path)
    gpu_rec = recovery_run(gpu_cool_path, gpu_path)

    rows = build_rows(baseline_runs[0][1], cpu_load, cpu_rec, gpu_load, gpu_rec)
    print_table(rows)
    print_summary(rows)


if __name__ == "__main__":
    main()
