#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="$repo_root/_build/browser-demo"
js_build_dir="$repo_root/_build/js/debug/build/cmd/browser"

cd "$repo_root"

moon build --target js cmd/browser

mkdir -p "$out_dir"
rm -f "$out_dir/main.js" "$out_dir/main.js.map"
cp "$repo_root/browser_demo/index.html" "$out_dir/index.html"
cp "$repo_root/browser_demo/styles.css" "$out_dir/styles.css"
cp "$js_build_dir/browser.js" "$out_dir/browser.js"
if [[ -f "$js_build_dir/browser.js.map" ]]; then
  cp "$js_build_dir/browser.js.map" "$out_dir/browser.js.map"
fi

printf 'browser demo artifact: %s\n' "$out_dir/index.html"
