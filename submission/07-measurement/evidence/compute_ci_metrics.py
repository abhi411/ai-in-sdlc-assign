#!/usr/bin/env python3
"""Baseline CI metrics from ops/pipeline/run-timings.csv. Usage: python3 compute_ci_metrics.py run-timings.csv"""
import csv, sys, math, statistics as st
from collections import OrderedDict
from datetime import datetime

def wilson(k, n, z=1.96):
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    m = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n))
    return (c - m) / d, (c + m) / d

rows = list(csv.DictReader(open(sys.argv[1] if len(sys.argv) > 1 else "run-timings.csv")))
runs = OrderedDict()
for r in rows:
    run = runs.setdefault(int(r["run_number"]), {"meta": r, "dur": 0, "steps": {}})
    run["dur"] += int(r["duration_seconds"])
    run["steps"][r["step"]] = int(r["duration_seconds"])

n = len(runs)
durs = sorted(v["dur"] for v in runs.values())
fails = [k for k, v in runs.items() if v["meta"]["conclusion"] != "success"]
lo, hi = wilson(len(fails), n)
ts = lambda s: datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")
print(f"runs analysed: {n}  window: {runs[1]['meta']['started_at']} .. {runs[n]['meta']['started_at']}")
print(f"pipeline wall-clock (sum of step durations): median {st.median(durs):.0f}s = {st.median(durs)/60:.1f} min, "
      f"min {durs[0]}s, max {durs[-1]}s, p90 {durs[int(0.9*(n-1))]}s")
print(f"run failure rate: {len(fails)}/{n} = {len(fails)/n:.0%}  (95% Wilson interval {lo:.0%} to {hi:.0%})")
for k in fails:
    m = runs[k]["meta"]
    later = [j for j, v in runs.items() if j > k and v["meta"]["branch"] == m["branch"] and v["meta"]["conclusion"] == "success"]
    rec = ""
    if later:
        j = later[0]
        rec = f", next green run on same branch: #{j} after {(ts(runs[j]['meta']['started_at'])-ts(m['started_at'])).total_seconds()/3600:.1f} h"
    print(f"  failed run #{k} branch={m['branch']} event={m['event']} started={m['started_at']}{rec}")
by_step = {}
for v in runs.values():
    for s, d in v["steps"].items():
        by_step.setdefault(s, []).append(d)
total = sum(sum(x) for x in by_step.values())
print("slowest steps by share of total CI time:")
for s, x in sorted(by_step.items(), key=lambda kv: -sum(kv[1]))[:5]:
    print(f"  {s}: median {st.median(x):.0f}s, {sum(x)/total:.1%} of all CI time")
