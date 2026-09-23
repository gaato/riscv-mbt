# Task 0054: Browser Linux Observability Refactor

## Background

Once Linux boots in the browser, the result needs to be maintainable. The final refactor slice should turn the proof into a repeatable development surface without making the browser host the only way to debug the emulator.

## Work

- Tighten browser boot status reporting and failure visibility
- Add or update smoke verification for the browser Wasm artifact
- Keep performance and memory limits documented
- Keep native tests and browser verification responsibilities separate

## Acceptance Criteria

- Browser Linux boot has a documented verification path
- Failure modes are visible from the browser UI or generated logs
- The milestone can close without hiding core emulator behavior behind UI-only checks

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0053](0053-browser-one-hart-linux-boot.md)

## Status

- `done`

## Progress Notes

- This is the final refactor task in the implementation/refactor alternating sequence for the browser Wasm Linux boot goal
- The browser status panel now reports serial boot marker progress separately from raw console text so long Linux runs have a compact progress surface.
- Verification path is documented by `outputs/webwright_browser_linux_boot/plan.md` and `outputs/webwright_browser_linux_boot/final_runs/run_1/final_script.py`.
- The bare-metal browser smoke proof is also self-contained in `outputs/webwright_wasm_smoke/final_runs/run_1/final_script.py`; it starts its local server before driving Chromium.
- The browser proof remains separate from native emulator coverage; `moon test` still runs the native Linux boot path.
- [Task 0055](0055-browser-plain-wasm-backend.md) later preserved this verification surface after moving the shipped browser artifact from `wasm-gc` to plain `wasm`.
