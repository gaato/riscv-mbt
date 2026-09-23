# Task 0050: Browser Runtime Boundary Refactor

## Background

Before Linux artifacts are loaded in the browser, the browser runtime boundary needs to be explicit. The host should own UI, artifact loading, and scheduling; the emulator core should remain reusable outside the browser.

## Work

- Separate browser UI control code from emulator runtime wiring
- Define a small host-facing runtime surface for reset, step/run, serial input, serial drain, and status
- Keep guest artifact loading outside instruction execution and CPU state code
- Preserve the Wasm smoke behavior from Task 0049

## Acceptance Criteria

- Browser runtime concerns are isolated from core emulator behavior
- The host-facing API is small enough to support both bare-metal smoke and later Linux boot artifacts
- Existing native and browser smoke checks remain green

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0049](0049-browser-wasm-smoke-host.md)

## Status

- `done`

## Progress Notes

- This is the first refactor task in the implementation/refactor alternating sequence
- Task 0049 already introduced an initial Wasm runtime surface; this task should tighten that boundary rather than expand Linux artifact scope
- The browser package is now split into `demo_guest.mbt`, `runtime.mbt`, and `main.mbt` so guest image construction, runtime state, and exported Wasm wrappers are separate
- Browser JS now wraps the raw Wasm exports in a `makeBrowserRuntime(...)` object; UI event handlers no longer call export names directly
- The refactor preserved the Wasm smoke behavior verified by `moon test`, `./scripts/build-browser-demo.sh`, and `outputs/webwright_wasm_smoke/final_runs/run_1/final_script.py`
