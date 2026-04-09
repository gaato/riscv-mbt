#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR_RV32="${RISCV_TESTS_DIR_RV32:-${RISCV_TESTS_DIR:-$ROOT/_build/riscv-tests-src}}"
SRC_DIR_RV64="${RISCV_TESTS_DIR_RV64:-$ROOT/_build/riscv-tests-src-rv64}"
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

ensure_source_tree() {
  local src_dir="$1"
  if [ ! -d "$src_dir/.git" ]; then
    git clone --depth=1 https://github.com/riscv-software-src/riscv-tests "$src_dir"
  fi

  git -C "$src_dir" submodule update --init --recursive

  if [ ! -x "$src_dir/configure" ]; then
    (cd "$src_dir" && autoconf)
  fi
}

ensure_makefile_for_xlen() {
  local src_dir="$1"
  local xlen="$2"
  if [ ! -f "$src_dir/Makefile" ]; then
    local _riscv_install="${RISCV:-$HOME/.local/riscv}"
    (
      cd "$src_dir"
      CC="$CC_BIN" \
      CFLAGS="-nostdlib -nostartfiles" \
      LDFLAGS="-nostdlib -nostartfiles" \
      RISCV="$_riscv_install" \
        ./configure --prefix="$_riscv_install/target" --with-xlen="$xlen"
    )
  fi
}

source_dir_for_xlen() {
  local xlen="$1"
  case "$xlen" in
    32) printf '%s\n' "$SRC_DIR_RV32" ;;
    64) printf '%s\n' "$SRC_DIR_RV64" ;;
    *)
      echo "unsupported XLEN: $xlen" >&2
      exit 1
      ;;
  esac
}

xlen_for_arch() {
  local arch="$1"
  case "$arch" in
    rv64*) printf '64\n' ;;
    rv32*) printf '32\n' ;;
    *)
      echo "unsupported arch in manifest: $arch" >&2
      exit 1
      ;;
  esac
}

ensure_source_tree "$SRC_DIR_RV32"
ensure_makefile_for_xlen "$SRC_DIR_RV32" 32

while IFS=$'\t' read -r suite test_name arch tier; do
  if [[ -z "${suite}" || "${suite}" == \#* ]]; then
    continue
  fi

  xlen="$(xlen_for_arch "$arch")"
  src_dir="$(source_dir_for_xlen "$xlen")"
  ensure_source_tree "$src_dir"
  ensure_makefile_for_xlen "$src_dir" "$xlen"
  target="${suite}-p-${test_name}"
  echo "building ${target}"
  make -C "$src_dir/isa" "src_dir=$src_dir/isa" "XLEN=$xlen" "RISCV_PREFIX=${PREFIX}" "$target"
  "$STRIP_BIN" --strip-unneeded \
    -K tohost -K fromhost -K begin_signature -K end_signature \
    "$src_dir/isa/${target}"
done <"$MANIFEST_FILE"

echo "official riscv-tests targets from manifest built under $SRC_DIR_RV32/isa and $SRC_DIR_RV64/isa"
