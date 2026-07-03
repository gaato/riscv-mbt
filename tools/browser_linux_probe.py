#!/usr/bin/env python3
import argparse
import html
from pathlib import Path
import re
import socket
import subprocess
import sys
import time
import urllib.parse


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


def pick_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_server(port: int) -> None:
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.2)
            if sock.connect_ex(("127.0.0.1", port)) == 0:
                return
        time.sleep(0.05)
    raise RuntimeError(f"HTTP server did not start on port {port}")


def start_http_server(directory: str, port: int) -> subprocess.Popen:
    process = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "http.server",
            str(port),
            "--bind",
            "127.0.0.1",
            "--directory",
            directory,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        wait_for_server(port)
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
        raise
    return process


def alpine_interactive_url(
    base_url: str,
    command: str,
    expect_marker: str,
    linux_steps_per_tick: int | None,
    sync_every_ticks: int | None,
    hot_pc_samples: int | None,
) -> str:
    params = {
        "guest": "linux",
        "autoRun": "1",
        "linuxInputAfterMarker": "/ #",
        "linuxInput": command,
        "linuxInputExpect": expect_marker,
        "haltOnLinuxInputExpect": "1",
    }
    if linux_steps_per_tick is not None:
        params["linuxStepsPerTick"] = str(linux_steps_per_tick)
    if sync_every_ticks is not None:
        params["syncEveryTicks"] = str(sync_every_ticks)
    if hot_pc_samples is not None:
        params["hotPcSamples"] = str(hot_pc_samples)
    query = urllib.parse.urlencode(params)
    return f"{base_url}/?{query}"


def hot_pc_status_lines(dom: str) -> list[str]:
    status_text = pre_text(dom, "status")
    if status_text is None:
        return []
    return [line for line in status_text.splitlines() if line.startswith("hot pc ")]


def pre_text(dom: str, element_id: str) -> str | None:
    match = re.search(rf'<pre id="{re.escape(element_id)}">(.*?)</pre>', dom, flags=re.DOTALL)
    if match is None:
        return None
    return html.unescape(match.group(1))


def print_probe_summary(dom: str) -> None:
    status_text = pre_text(dom, "status")
    artifact_text = pre_text(dom, "artifact-status")
    if artifact_text is not None:
        print("artifact status:")
        print(artifact_text)
    if status_text is not None:
        print("runtime status:")
        print(status_text)


def hot_pc_top_pcs(lines: list[str]) -> list[str]:
    for line in lines:
        if not line.startswith("hot pc top: "):
            continue
        pcs = []
        for entry in line.removeprefix("hot pc top: ").split():
            pc, _, _count = entry.rpartition(":")
            if pc:
                pcs.append(pc)
        return pcs
    return []


def print_hot_pc_summary(
    dom: str,
    system_map: str | None,
    image: str | None,
    context: int,
) -> None:
    lines = hot_pc_status_lines(dom)
    if not lines:
        print("hot pc summary: status node not found")
        return
    for line in lines:
        print(line)
    if system_map is None:
        return
    pcs = hot_pc_top_pcs(lines)
    if not pcs:
        print("hot pc resolve: no top PCs found")
        return
    resolver = Path(__file__).with_name("resolve_hot_pcs.py")
    cmd = [
        sys.executable,
        str(resolver),
        "--system-map",
        system_map,
        "--context",
        str(context),
    ]
    if image is not None:
        cmd.extend(["--image", image])
    else:
        cmd.append("--no-disasm")
    cmd.extend(pcs)
    result = subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.stderr:
        sys.stderr.write(result.stderr)
    if result.stdout:
        print("hot pc resolved:")
        sys.stdout.write(result.stdout)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("url", nargs="?")
    parser.add_argument("--marker", default="riscv-mbt Alpine initramfs ready")
    parser.add_argument("--budget-ms", type=int, default=600_000)
    parser.add_argument("--wall-timeout", type=float, default=900.0)
    parser.add_argument("--expect", action="append", default=[])
    parser.add_argument("--serve-dir")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--alpine-interactive-smoke", action="store_true")
    parser.add_argument("--input-command", default="echo browser-input-ok")
    parser.add_argument("--alpine-functional-smoke", action="store_true")
    parser.add_argument("--linux-steps-per-tick", type=int)
    parser.add_argument("--sync-every-ticks", type=int)
    parser.add_argument("--hot-pc-samples", type=int)
    parser.add_argument("--hot-pc-system-map")
    parser.add_argument("--hot-pc-image")
    parser.add_argument("--hot-pc-context", type=int, default=24)
    args = parser.parse_args()

    server = None
    url = args.url
    marker = args.marker
    expected = list(args.expect)
    if args.serve_dir:
        port = args.port if args.port != 0 else pick_free_port()
        server = start_http_server(args.serve_dir, port)
        base_url = f"http://127.0.0.1:{port}"
        if url is None:
            url = base_url
    if args.alpine_interactive_smoke and args.alpine_functional_smoke:
        parser.error("choose only one Alpine smoke mode")
    if args.alpine_interactive_smoke:
        if url is None:
            parser.error("--alpine-interactive-smoke requires a url or --serve-dir")
        marker = "browser-input-ok"
        expected.extend(["initrd 1443328 bytes", "/ #"])
        url = alpine_interactive_url(
            url.rstrip("/"),
            args.input_command,
            marker,
            args.linux_steps_per_tick,
            args.sync_every_ticks,
            args.hot_pc_samples,
        )
    if args.alpine_functional_smoke:
        if url is None:
            parser.error("--alpine-functional-smoke requires a url or --serve-dir")
        marker = "linux-functional-ok"
        command = (
            "mount -t proc proc /proc && "
            "mount -t sysfs sysfs /sys && "
            "echo file-ok > /tmp/riscv-mbt-file && "
            "cat /tmp/riscv-mbt-file && "
            "mkdir -p /tmp/riscv-mbt-dir && "
            "/bin/sh -c 'echo pipe-ok' | grep pipe-ok && "
            "uname -m && "
            "cat /proc/cpuinfo > /tmp/riscv-mbt-cpuinfo && "
            "echo linux-functional-ok"
        )
        expected.extend(["initrd 1443328 bytes", "/ #", "file-ok", "pipe-ok", "riscv64"])
        url = alpine_interactive_url(
            url.rstrip("/"),
            command,
            marker,
            args.linux_steps_per_tick,
            args.sync_every_ticks,
            args.hot_pc_samples,
        )
    if url is None:
        parser.error("url is required unless --serve-dir is used")

    try:
        dom = chromium_dump_dom(url, args.budget_ms, args.wall_timeout)
    except subprocess.TimeoutExpired:
        print(f"wall-clock timeout after {args.wall_timeout:.1f}s")
        return 4
    finally:
        if server is not None:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
    sys.stdout.write(dom[-5000:])
    sys.stdout.write("\n")
    print_probe_summary(dom)
    if args.hot_pc_samples is not None:
        print_hot_pc_summary(
            dom,
            args.hot_pc_system_map,
            args.hot_pc_image,
            args.hot_pc_context,
        )

    missing = [marker for marker in expected if marker not in dom]
    if missing:
        print(f"missing expected markers: {', '.join(missing)}")
        return 2
    if marker in dom:
        print(f"FOUND marker: {marker}")
        return 0
    if "[trap]" in dom:
        print("TRAP marker observed")
        return 3
    print(f"missing marker: {marker}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
