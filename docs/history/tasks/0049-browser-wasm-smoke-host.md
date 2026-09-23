# Task 0049: Browser Wasm Smoke Host

## Background

The current browser demo is a JS-target host over the shared emulator core. The new browser goal requires the browser path to move to the MoonBit Wasm target before Linux boot artifacts are connected.

## Work

- Change the browser build path from JS output to a Wasm browser artifact
- Keep the current bare-metal echo smoke program working
- Keep `cmd/browser` thin and avoid forking emulator behavior for the browser
- Update the build script and deployment artifact layout for Wasm

## Acceptance Criteria

- The browser build produces a Wasm-based artifact
- The existing serial console, UART input, step, run, and reset smoke flow still works
- Native `moon test` remains green
- Browser docs no longer describe the active browser host as JS-target only

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0020](0020-browser-demo.md)
- [Task 0022](0022-browser-smoke-demo-deploy.md)

## Status

- `done`

## Progress Notes

- This is the first implementation task in the implementation/refactor alternating sequence
- Linux artifacts stay out of scope until the Wasm smoke host is working
- The browser build first moved to `moon build --target wasm-gc cmd/browser`; [Task 0055](0055-browser-plain-wasm-backend.md) later moved the shipped browser artifact to plain `wasm`
- The browser host exposes a small Wasm runtime surface for init, step/run/reset, UART input, UART byte output, and status values
- A headless Chromium smoke verified the Wasm host note, initial `echo ready` prompt, `webwright-wasm-ok` UART echo, and populated status panel; evidence lives under `outputs/webwright_wasm_smoke/final_runs/run_1/`
