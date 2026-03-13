#!/usr/bin/env python3
"""
Parse gem5 m5out/stats.txt and print key metrics for CXL/LLM/DB optimization.
Usage: python3 analyze_gem5.py [path/to/stats.txt]
Default path: m5out/stats.txt
"""

import re
import sys
from pathlib import Path


def parse_gem5_stats(file_path: str) -> dict:
    """Extract metrics of interest from gem5 stats file."""
    metrics = {
        "Ticks": r"sim_ticks\s+(\d+)",
        "L1_Misses": r"system\.ruby\.l1_cntrl0\.L1Dcache\.misses\s+(\d+)",
        "Coherence_Messages": r"system\.ruby\.network\.control_msg_count\s+(\d+)",
        "Avg_Mem_Latency": r"system\.ruby\.network\.average_packet_latency\s+([\d\.]+)",
        "Total_Instructions": r"system\.cpu0\.numInsts\s+(\d+)",
        # Fallbacks / alternate names (gem5 version-dependent)
        "sim_seconds": r"sim_seconds\s+([\d\.]+)",
        "host_inst_rate": r"host_inst_rate\s+([\d\.]+)",
    }
    # More flexible: any cpu numInsts
    metrics["Total_Instructions_any"] = r"system\.cpu\d*\.numInsts\s+(\d+)"

    results = {}
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"Stats file not found: {file_path}")

    content = path.read_text()

    for name, pattern in metrics.items():
        if name.endswith("_any"):
            continue
        match = re.search(pattern, content)
        if match:
            val = match.group(1)
            try:
                results[name] = int(val)
            except ValueError:
                results[name] = float(val)

    # Fallback for Total_Instructions if cpu0 not found
    if "Total_Instructions" not in results:
        m = re.search(metrics["Total_Instructions_any"], content)
        if m:
            results["Total_Instructions"] = int(m.group(1))

    # Derived: CPI (cycles per instruction), approximate
    if "Ticks" in results and "Total_Instructions" in results and results["Total_Instructions"] > 0:
        # Assume 1GHz for display; real CPI = Ticks / (Instructions * period)
        results["CPI"] = results["Ticks"] / (results["Total_Instructions"] * 1000)

    return results


def main():
    stats_path = sys.argv[1] if len(sys.argv) > 1 else "m5out/stats.txt"
    try:
        data = parse_gem5_stats(stats_path)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        sys.exit(1)

    print("--- gem5 simulation metrics ---")
    for k, v in sorted(data.items()):
        if isinstance(v, float):
            print(f"  {k:25}: {v:>14.4f}")
        else:
            print(f"  {k:25}: {v:>14}")
    print("---")
    print("Interpretation: lower Coherence_Messages / Avg_Mem_Latency often better for CXL/LLM tuning.")


if __name__ == "__main__":
    main()
