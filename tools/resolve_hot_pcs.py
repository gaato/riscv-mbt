#!/usr/bin/env python3
"""Resolve sampled Linux kernel PCs with System.map and optional Image bytes."""

from __future__ import annotations

import argparse
import bisect
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Symbol:
    addr: int
    kind: str
    name: str


def parse_int(value: str) -> int:
    value = value.strip()
    if value.lower().startswith("0x") or any(c in value.lower() for c in "abcdef"):
        return int(value, 16)
    return int(value, 0)


def read_system_map(path: Path) -> list[Symbol]:
    symbols: list[Symbol] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) < 3:
                continue
            try:
                addr = int(parts[0], 16)
            except ValueError:
                continue
            symbols.append(Symbol(addr=addr, kind=parts[1], name=parts[2]))
    symbols.sort(key=lambda symbol: (symbol.addr, symbol.name))
    return symbols


def find_symbol(symbols: list[Symbol], pc: int) -> Symbol | None:
    addrs = [symbol.addr for symbol in symbols]
    index = bisect.bisect_right(addrs, pc) - 1
    if index < 0:
        return None
    return symbols[index]


def symbol_by_name(symbols: list[Symbol], name: str) -> Symbol | None:
    for symbol in symbols:
        if symbol.name == name:
            return symbol
    return None


def disassemble_window(image: Path, pc: int, image_base: int, context: int) -> str | None:
    objdump = shutil.which("riscv64-linux-gnu-objdump") or shutil.which("llvm-objdump") or shutil.which("objdump")
    if objdump is None:
        return None

    offset = pc - image_base
    image_size = image.stat().st_size
    if offset < 0 or offset >= image_size:
        return None

    start = max(0, offset - context)
    start &= ~0x1
    end = min(image_size, offset + context)
    data = image.read_bytes()[start:end]

    with tempfile.NamedTemporaryFile(prefix="riscv-mbt-hot-pc-", suffix=".bin", delete=False) as handle:
        handle.write(data)
        temp_name = handle.name
    try:
        vma = image_base + start
        if Path(objdump).name == "llvm-objdump":
            cmd = [
                objdump,
                "--triple=riscv64",
                "--disassemble-all",
                f"--adjust-vma=0x{vma:x}",
                temp_name,
            ]
        else:
            cmd = [
                objdump,
                "-D",
                "-b",
                "binary",
                "-m",
                "riscv:rv64",
                f"--adjust-vma=0x{vma:x}",
                temp_name,
            ]
        proc = subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if proc.returncode != 0:
            return proc.stderr.strip() or None
        lines = []
        for line in proc.stdout.splitlines():
            stripped = line.strip()
            prefix = f"{pc:x}:"
            if stripped.startswith(prefix):
                lines.append("=> " + line)
            elif stripped and any(stripped.startswith(f"{addr:x}:") for addr in range(pc - 8, pc + 10, 2)):
                lines.append("   " + line)
        return "\n".join(lines) if lines else proc.stdout.strip()
    finally:
        try:
            os.unlink(temp_name)
        except OSError:
            pass


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Resolve sampled Linux kernel PCs using System.map and optional raw kernel Image bytes."
    )
    parser.add_argument("pcs", nargs="+", help="PC values, decimal, bare hex, or 0x-prefixed hex")
    parser.add_argument("--system-map", type=Path, required=True, help="Linux System.map path")
    parser.add_argument("--image", type=Path, help="Raw Linux kernel Image path for disassembly")
    parser.add_argument("--base-symbol", default="_start", help="Image base symbol name (default: _start)")
    parser.add_argument("--context", type=int, default=32, help="Disassembly context bytes on each side")
    parser.add_argument("--no-disasm", action="store_true", help="Only print symbol mappings")
    args = parser.parse_args(argv)

    symbols = read_system_map(args.system_map)
    if not symbols:
        print(f"no symbols found in {args.system_map}", file=sys.stderr)
        return 1

    base_symbol = symbol_by_name(symbols, args.base_symbol)
    image_base = base_symbol.addr if base_symbol is not None else None
    if args.image and not args.no_disasm and image_base is None:
        print(f"base symbol {args.base_symbol!r} not found; disabling disassembly", file=sys.stderr)

    for pc_text in args.pcs:
        pc = parse_int(pc_text)
        symbol = find_symbol(symbols, pc)
        if symbol is None:
            print(f"0x{pc:016x}: <no symbol>")
            continue
        delta = pc - symbol.addr
        print(f"0x{pc:016x}: {symbol.name}+0x{delta:x} ({symbol.kind} 0x{symbol.addr:016x})")
        if args.image and not args.no_disasm and image_base is not None:
            disasm = disassemble_window(args.image, pc, image_base, args.context)
            if disasm:
                print(disasm)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
