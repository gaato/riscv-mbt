#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_TAG="${PODMAN_IMAGE_TAG:-riscv-mbt-riscv-tests}"
CONTAINERFILE="${PODMAN_CONTAINERFILE:-$ROOT/tools/podman/riscv-tests/Containerfile}"

if ! command -v podman >/dev/null 2>&1; then
  echo "missing required tool: podman" >&2
  exit 1
fi

podman build -t "$IMAGE_TAG" -f "$CONTAINERFILE" "$ROOT"

podman run --rm \
  -v "$ROOT:/workspace:Z" \
  -w /workspace \
  "$IMAGE_TAG" \
  bash -lc './scripts/build-riscv-tests-official.sh'

