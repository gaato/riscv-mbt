#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/build-riscv-tests-official.sh"
bash "$ROOT/scripts/update-riscv-tests-official-generated.sh"

if ! git -C "$ROOT" diff --exit-code -- riscv_tests_official_generated.mbt; then
  echo >&2
  echo "riscv_tests_official_generated.mbt is out of date." >&2
  echo "Run ./scripts/check-riscv-tests-official-generated.sh locally and commit the regenerated file." >&2
  exit 1
fi
