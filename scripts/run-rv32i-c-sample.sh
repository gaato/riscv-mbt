#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/build-rv32i-c-sample.sh"
moon run "$ROOT/cmd/c_sample"
