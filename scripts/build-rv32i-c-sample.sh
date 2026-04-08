#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE_DIR="$ROOT/tools/c-samples/rv32i-sum"
OUT_DIR="$ROOT/_build/c-samples/rv32i-sum"

detect_prefix() {
  if [ -n "${RISCV_PREFIX:-}" ]; then
    printf '%s\n' "$RISCV_PREFIX"
    return
  fi

  for candidate in riscv64-unknown-elf- riscv64-elf-; do
    if command -v "${candidate}gcc" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "missing supported RISC-V toolchain prefix; tried riscv64-unknown-elf- and riscv64-elf-" >&2
  exit 1
}

PREFIX="$(detect_prefix)"
CC_BIN="${CC_BIN:-${PREFIX}gcc}"
OBJDUMP_BIN="${OBJDUMP_BIN:-${PREFIX}objdump}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

require_tool "$CC_BIN"
require_tool "$OBJDUMP_BIN"
require_tool mkdir

mkdir -p "$OUT_DIR"

ELF_PATH="$OUT_DIR/rv32i-sum.elf"
MAP_PATH="$OUT_DIR/rv32i-sum.map"
DISASM_PATH="$OUT_DIR/rv32i-sum.dump"

"$CC_BIN" \
  -march=rv32i \
  -mabi=ilp32 \
  -nostdlib \
  -ffreestanding \
  -O2 \
  -Wl,-T,"$SAMPLE_DIR/link.ld" \
  -Wl,-Map,"$MAP_PATH" \
  "$SAMPLE_DIR/start.S" \
  "$SAMPLE_DIR/main.c" \
  -o "$ELF_PATH"

"$OBJDUMP_BIN" -d "$ELF_PATH" >"$DISASM_PATH"

echo "built RV32I C sample:"
echo "  ELF:     $ELF_PATH"
echo "  map:     $MAP_PATH"
echo "  disasm:  $DISASM_PATH"
