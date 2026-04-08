#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${RISCV_TESTS_DIR:-$ROOT/_build/riscv-tests-src}"
MANIFEST_FILE="$ROOT/tools/riscv-tests-manifest.tsv"
detect_prefix() {
  if [ -n "${RISCV_PREFIX:-}" ]; then
    printf '%s\n' "$RISCV_PREFIX"
    return
  fi

  for candidate in riscv64-unknown-elf- riscv64-elf-; do
    if command -v "${candidate}gcc" >/dev/null 2>&1 &&
      command -v "${candidate}strip" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  echo "missing supported RISC-V toolchain prefix; tried riscv64-unknown-elf- and riscv64-elf-" >&2
  exit 1
}

PREFIX="$(detect_prefix)"
CC_BIN="${CC_BIN:-${PREFIX}gcc}"
STRIP_BIN="${STRIP_BIN:-${PREFIX}strip}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

require_tool git
require_tool autoconf
require_tool make
require_tool "$CC_BIN"
require_tool "$STRIP_BIN"

if [ ! -d "$SRC_DIR/.git" ]; then
  git clone --depth=1 https://github.com/riscv-software-src/riscv-tests "$SRC_DIR"
fi

git -C "$SRC_DIR" submodule update --init --recursive

if [ ! -x "$SRC_DIR/configure" ]; then
  (cd "$SRC_DIR" && autoconf)
fi

if [ ! -f "$SRC_DIR/Makefile" ]; then
  _riscv_install="${RISCV:-$HOME/.local/riscv}"
  (
    cd "$SRC_DIR"
    CC="$CC_BIN" \
    CFLAGS="-nostdlib -nostartfiles" \
    LDFLAGS="-nostdlib -nostartfiles" \
    RISCV="$_riscv_install" \
      ./configure --prefix="$_riscv_install/target" --with-xlen=32
  )
fi

while IFS=$'\t' read -r suite test_name arch tier; do
  if [[ -z "${suite}" || "${suite}" == \#* ]]; then
    continue
  fi

  target="${suite}-p-${test_name}"
  echo "building ${target}"
  make -C "$SRC_DIR/isa" "src_dir=$SRC_DIR/isa" XLEN=32 "RISCV_PREFIX=${PREFIX}" "$target"
  "$STRIP_BIN" --strip-unneeded \
    -K tohost -K fromhost -K begin_signature -K end_signature \
    "$SRC_DIR/isa/${target}"
done <"$MANIFEST_FILE"

echo "official riscv-tests targets from manifest built under $SRC_DIR/isa"
