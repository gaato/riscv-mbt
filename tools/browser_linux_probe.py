#!/usr/bin/env python3
import argparse
import subprocess
import sys


def chromium_dump_dom(
    url: str,
    virtual_time_budget_ms: int,
    wall_timeout_s: float,
) -> str:
    result = subprocess.run(
        [
            "chromium",
            "--headless=new",
            "--no-sandbox",
            "--disable-gpu",
            f"--virtual-time-budget={virtual_time_budget_ms}",
            "--dump-dom",
            url,
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=wall_timeout_s,
    )
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--marker", default="riscv-mbt Alpine initramfs ready")
    parser.add_argument("--budget-ms", type=int, default=600_000)
    parser.add_argument("--wall-timeout", type=float, default=900.0)
    parser.add_argument("--expect", action="append", default=[])
    args = parser.parse_args()

    try:
        dom = chromium_dump_dom(args.url, args.budget_ms, args.wall_timeout)
    except subprocess.TimeoutExpired:
        print(f"wall-clock timeout after {args.wall_timeout:.1f}s")
        return 4
    sys.stdout.write(dom[-5000:])
    sys.stdout.write("\n")

    missing = [marker for marker in args.expect if marker not in dom]
    if missing:
      print(f"missing expected markers: {', '.join(missing)}")
      return 2
    if args.marker in dom:
        print(f"FOUND marker: {args.marker}")
        return 0
    if "[trap]" in dom:
        print("TRAP marker observed")
        return 3
    print(f"missing marker: {args.marker}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
