# Task 0055: Move Browser Host To Plain Wasm Backend

## Background

The browser Linux boot path first used MoonBit's `wasm-gc` backend with JS builtin string interop. That proved the browser delivery goal, but it left the browser ABI tied to `wasm:js-string` imports and browser GC/string proposal support.

The next backend slice checks whether the same browser host can use MoonBit's plain `wasm` backend instead.

## Work

- Build `cmd/browser` with `moon build --target wasm`
- Remove browser JS reliance on MoonBit `String` parameters for host input and artifact loading
- Use a byte-oriented browser ABI for UART input and Linux artifacts
- Preserve the browser smoke path
- Preserve browser Linux boot to early serial output
- Record differences from the previous `wasm-gc` backend

## Acceptance Criteria

- `./scripts/build-browser-demo.sh` produces `_build/browser-demo/browser.wasm` from the plain `wasm` backend
- The browser smoke proof still echoes UART input through the Wasm host
- The browser Linux boot proof reaches early Linux serial markers
- Docs record the `wasm` vs `wasm-gc` ABI and artifact-size differences

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0054](0054-browser-linux-observability-refactor.md)

## Status

- `done`

## Progress Notes

- The browser build script now runs `moon build --target wasm cmd/browser` and copies `_build/wasm/debug/build/cmd/browser/browser.wasm`.
- The browser JS glue now instantiates a plain Wasm module with no required imports for the active backend.
- Browser UART input uses `browser_send_input_byte` plus `browser_flush_input` instead of passing JavaScript strings into MoonBit.
- Linux artifact loading uses a packed byte ABI: `browser_push_artifact_words4` transfers up to 16 artifact bytes per JS-to-Wasm call while keeping the public data boundary byte-oriented.
- Current build observation: plain `wasm` browser artifact is 280660 bytes with 0 imports and 22 exports; current `wasm-gc` build is 134502 bytes with 44 imports, including 39 imported string constants and 5 `wasm:js-string` functions.
- Browser Linux boot proof on the plain `wasm` backend reached `Linux version`, `earlycon`, and `Kernel command line`; the measured wall-clock time for the current final script run was 609.38 seconds.
- [Task 0056](0056-simmerv-inspired-cache-performance.md) later reduced the same browser Linux boot proof to 349.33 seconds by adding decode and translation caches.
