# Plain Wasm Backend Observations

- Build command: `./scripts/build-browser-demo.sh`
- Active backend: `moon build --target wasm cmd/browser`
- Active browser artifact: `_build/browser-demo/browser.wasm`
- Active artifact size: 280660 bytes
- Active Wasm import count: 0
- Comparison `wasm-gc` artifact size from the same source tree: 134502 bytes
- Comparison `wasm-gc` import count: 44
- Comparison `wasm-gc` imports: 39 `_` globals and 5 `wasm:js-string` functions
- Smoke proof: `outputs/webwright_wasm_smoke/final_runs/run_1/final_script.py`
- Linux proof: `outputs/webwright_browser_linux_boot/final_runs/run_1/final_script.py`
- Linux proof result: reached `Linux version`, `earlycon`, and `Kernel command line`
- Linux proof timing command: `/usr/bin/time -f 'elapsed_seconds=%e' python3 outputs/webwright_browser_linux_boot/final_runs/run_1/final_script.py`
- Linux proof observed wall-clock time: 609.38 seconds
- After `0056` decode/translation cache work, the same browser Linux proof observed wall-clock time was 349.33 seconds.
