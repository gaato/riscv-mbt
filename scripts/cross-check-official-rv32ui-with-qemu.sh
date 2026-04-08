#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${RISCV_TESTS_DIR:-$ROOT/_build/riscv-tests-src}"
ISA_DIR="$SRC_DIR/isa"
MANIFEST_FILE="$ROOT/tools/riscv-tests-manifest.tsv"
QEMU_BIN="${QEMU_BIN:-qemu-system-riscv32}"

detect_readelf() {
  if [ -n "${READELF_BIN:-}" ]; then
    printf '%s\n' "$READELF_BIN"
    return
  fi

  for candidate in riscv64-unknown-elf-readelf riscv64-elf-readelf; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "missing supported RISC-V readelf; tried riscv64-unknown-elf-readelf and riscv64-elf-readelf" >&2
  exit 1
}

READELF_BIN="$(detect_readelf)"
POLL_ATTEMPTS="${QEMU_POLL_ATTEMPTS:-200}"
POLL_INTERVAL="${QEMU_POLL_INTERVAL_SEC:-0.05}"
SOCKET_ATTEMPTS="${QEMU_SOCKET_ATTEMPTS:-100}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

require_tool "$QEMU_BIN"
require_tool "$READELF_BIN"
require_tool socat
require_tool awk
require_tool perl
require_tool sed

if [ ! -d "$ISA_DIR" ]; then
  echo "missing official riscv-tests build output under $ISA_DIR" >&2
  echo "run ./scripts/build-riscv-tests-official.sh first" >&2
  exit 1
fi

strip_monitor_output() {
  perl -pe 's/\e\[[0-9;]*[A-Za-z]//g'
}

read_symbol_addr() {
  local elf="$1"
  local symbol="$2"
  "$READELF_BIN" -sW "$elf" | awk -v symbol="$symbol" '$8 == symbol { print $2; exit }'
}

read_hmp_u32() {
  local monitor_socket="$1"
  local address_hex="$2"
  local raw
  raw=$(printf 'xp/1wx 0x%s\n' "$address_hex" | socat - UNIX-CONNECT:"$monitor_socket")
  printf '%s' "$raw" \
    | strip_monitor_output \
    | sed -n 's/^00000000[0-9a-fA-F]*: 0x\([0-9a-fA-F]\+\).*/0x\1/p' \
    | tail -n 1
}

read_register_snapshot() {
  local monitor_socket="$1"
  printf 'info registers\n' | socat - UNIX-CONNECT:"$monitor_socket" | strip_monitor_output
}

normalize_test_name() {
  local input="$1"
  if [[ "$input" == rv32ui-p-* ]]; then
    printf '%s\n' "${input#rv32ui-p-}"
  else
    printf '%s\n' "$input"
  fi
}

load_default_tests() {
  awk -F '\t' '$1 == "rv32ui" && $4 == "gating" { print $2 }' "$MANIFEST_FILE"
}

run_one() {
  local short_name="$1"
  local elf="$ISA_DIR/rv32ui-p-$short_name"

  if [ ! -f "$elf" ]; then
    echo "missing official test binary: $elf" >&2
    return 1
  fi

  local tohost
  tohost=$(read_symbol_addr "$elf" tohost)
  if [ -z "$tohost" ]; then
    echo "failed to locate tohost in $elf" >&2
    return 1
  fi

  local temp_dir
  temp_dir=$(mktemp -d)
  local monitor_socket="$temp_dir/monitor.sock"
  local qemu_stdout="$temp_dir/qemu.stdout"
  local qemu_stderr="$temp_dir/qemu.stderr"
  local qemu_pid=""

  cleanup_one() {
    if [ -n "$qemu_pid" ] && kill -0 "$qemu_pid" >/dev/null 2>&1; then
      kill "$qemu_pid" >/dev/null 2>&1 || true
      wait "$qemu_pid" >/dev/null 2>&1 || true
    fi
    rm -rf "$temp_dir"
  }
  trap cleanup_one RETURN

  "$QEMU_BIN" \
    -machine virt \
    -bios none \
    -nographic \
    -kernel "$elf" \
    -monitor unix:"$monitor_socket",server,nowait \
    -serial none \
    -display none \
    >"$qemu_stdout" 2>"$qemu_stderr" &
  qemu_pid=$!

  local socket_ready=0
  for _ in $(seq 1 "$SOCKET_ATTEMPTS"); do
    if [ -S "$monitor_socket" ]; then
      socket_ready=1
      break
    fi
    if ! kill -0 "$qemu_pid" >/dev/null 2>&1; then
      break
    fi
    sleep "$POLL_INTERVAL"
  done

  if [ "$socket_ready" -ne 1 ]; then
    echo "qemu monitor socket was not ready for rv32ui-p-$short_name" >&2
    sed -n '1,80p' "$qemu_stderr" >&2 || true
    return 1
  fi

  local tohost_value="0x00000000"
  for _ in $(seq 1 "$POLL_ATTEMPTS"); do
    if ! kill -0 "$qemu_pid" >/dev/null 2>&1; then
      echo "qemu exited early while running rv32ui-p-$short_name" >&2
      sed -n '1,80p' "$qemu_stderr" >&2 || true
      return 1
    fi

    tohost_value=$(read_hmp_u32 "$monitor_socket" "$tohost")
    if [ -n "$tohost_value" ] && [ "$tohost_value" != "0x00000000" ]; then
      break
    fi
    sleep "$POLL_INTERVAL"
  done

  if [ "$tohost_value" = "0x00000000" ]; then
    echo "timeout waiting for tohost in rv32ui-p-$short_name" >&2
    read_register_snapshot "$monitor_socket" | sed -n '1,80p' >&2 || true
    sed -n '1,80p' "$qemu_stderr" >&2 || true
    return 1
  fi

  if [ "$tohost_value" != "0x00000001" ]; then
    echo "rv32ui-p-$short_name reported failure through tohost=$tohost_value" >&2
    read_register_snapshot "$monitor_socket" | sed -n '1,80p' >&2 || true
    return 1
  fi

  echo "PASS rv32ui-p-$short_name (tohost=$tohost_value)"
}

declare -a tests=()
if [ "$#" -gt 0 ]; then
  for arg in "$@"; do
    tests+=("$(normalize_test_name "$arg")")
  done
else
  while IFS= read -r name; do
    tests+=("$name")
  done < <(load_default_tests)
fi

if [ "${#tests[@]}" -eq 0 ]; then
  echo "no tests selected" >&2
  exit 1
fi

for name in "${tests[@]}"; do
  run_one "$name"
done
