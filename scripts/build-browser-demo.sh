#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="$repo_root/_build/browser-demo"
wasm_build_dir="$repo_root/_build/wasm/debug/build/cmd/browser"

cd "$repo_root"

moon build --target wasm cmd/browser

mkdir -p "$out_dir"
rm -f "$out_dir/browser.js" "$out_dir/browser.js.map" "$out_dir/browser.wasm"
rm -rf "$out_dir/linux-artifacts"
cp "$repo_root/browser_demo/index.html" "$out_dir/index.html"
cp "$repo_root/browser_demo/.nojekyll" "$out_dir/.nojekyll"
cp "$repo_root/browser_demo/styles.css" "$out_dir/styles.css"
cp "$repo_root/browser_demo/browser.js" "$out_dir/browser.js"
cp "$wasm_build_dir/browser.wasm" "$out_dir/browser.wasm"
mkdir -p "$out_dir/linux-artifacts"
cp "$repo_root/browser_demo/linux-artifacts/manifest.json" "$out_dir/linux-artifacts/manifest.json"
for artifact in \
  opensbi-riscv64-fw_dynamic.bin \
  minimal.dtb \
  minimal-alpine.dtb \
  linux-kernel-riscv64 \
  alpine-initramfs-riscv64.cpio.gz
do
  if [[ -f "$repo_root/_build/$artifact" ]]; then
    cp "$repo_root/_build/$artifact" "$out_dir/linux-artifacts/$artifact"
  fi
done

printf 'browser demo artifact: %s\n' "$out_dir/index.html"
