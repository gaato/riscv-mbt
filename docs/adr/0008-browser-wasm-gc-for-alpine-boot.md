# ADR 0008: Use `wasm-gc` As The Browser Alpine Boot Default

## Status

Accepted

## Context

ADR 0007 moved the browser host to MoonBit's plain `wasm` backend because the emulator has a large linear-memory-shaped workload and JS can naturally interact with `WebAssembly.Memory`.

The Alpine rootfs goal changes the decision pressure. The browser workload is now dominated by long MoonBit execution through Linux boot and initramfs unpacking. The host ABI already streams artifact bytes through exported functions and does not require JS to directly inspect emulator RAM.

MoonBit docs still support both `wasm` and `wasm-gc` targets for the browser package. The Zenn MoonBit optimization article and MoonBit v0.10 direction both suggest that backend choice should be measured rather than assumed.

## Decision

Use `wasm-gc` as the default browser demo backend for the Alpine rootfs boot path. Keep `BROWSER_TARGET=wasm` available for comparison and fallback.

## Evidence

- `moon build --target wasm-gc cmd/browser` passes.
- `wasm-gc` browser artifact size is about 151 KB versus about 236 KB for plain `wasm` in the current debug build.
- With the same Alpine artifacts and 180s Chromium virtual-time probe, `wasm-gc` reached the same Linux initramfs unpack point as plain `wasm` but returned substantially faster in wall-clock time.
- Neither backend reaches the injected Alpine `/init` marker yet; backend selection is therefore a performance baseline, not task completion.

## Consequences

- `./scripts/build-browser-demo.sh` defaults to `wasm-gc`.
- Backend comparisons should use `BROWSER_TARGET=wasm` and `BROWSER_TARGET=wasm-gc` with the same artifact set and marker probe.
- Core emulator code should remain backend-neutral unless a benchmark justifies a backend-specific optimization.
