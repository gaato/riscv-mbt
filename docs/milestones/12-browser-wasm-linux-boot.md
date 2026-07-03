# Milestone 12: Browser Wasm Linux Boot

## Purpose

Run the existing Linux-capable emulator core in the browser through the MoonBit Wasm target, and make the browser host capable of booting the same OpenSBI + Linux path that is already validated outside the browser.

## Target Instructions / Features

- MoonBit Wasm browser artifact
- Thin browser host over the shared core
- Browser-loadable OpenSBI, DTB, and Linux kernel artifacts
- One-hart Linux boot through the browser serial console
- Step/run/reset controls that remain usable during long boot runs
- Clear separation between browser host code, guest artifact loading, and core emulator behavior

## Non-Goals

- Replacing the native Linux boot tests
- Full IDE-like front-end
- SMP-in-browser before one-hart browser Linux boot is stable
- Implementing unrelated ISA families while the browser boot path is being wired

## Exit Criteria

- The browser build uses the Wasm target rather than the current JS target
- The existing bare-metal browser smoke demo still works after the target change
- The browser host can load or embed the required OpenSBI, DTB, and Linux kernel artifacts
- Linux emits early boot logs through the browser serial console on one hart
- The work alternates implementation and refactor tasks so large host/core boundary changes do not accumulate silently

## Required Tests

- Native `moon test`
- Browser build check for the Wasm artifact
- Browser smoke check for the existing bare-metal echo path
- Browser smoke check for OpenSBI/Linux serial output once the artifact loader exists

## Implementation Order

1. implementation: switch the browser build to Wasm while preserving the existing smoke demo
2. refactor: isolate browser host, artifact loading, and emulator runtime boundaries
3. implementation: add browser-loadable OpenSBI, DTB, and Linux kernel artifacts
4. refactor: make long browser runs, memory sizing, and serial draining explicit
5. implementation: boot Linux on one hart in the browser Wasm host
6. refactor: tighten browser verification, observability, and performance guardrails

## Current Checkpoint

- This milestone is complete
- The prior browser milestone delivered a JS-target bare-metal smoke demo
- The non-browser emulator already has a Linux boot path
- The browser artifact first moved through the Wasm GC target, then plain `wasm`, and now defaults back to `wasm-gc` for the Alpine rootfs path based on initial measurement while preserving `BROWSER_TARGET=wasm` as a fallback
- The runtime boundary now separates guest construction, browser runtime state, Wasm exports, and JS UI glue
- The browser can load OpenSBI, DTB, and kernel artifact bytes through a manifest and switch to the Linux artifact guest
- Long-run scheduling, executed-step reporting, and artifact-size visibility are now explicit in the browser host
- Real OpenSBI, generated DTB, and the Debian riscv64 kernel artifact now reach early Linux serial output in browser Wasm
- Browser status reporting now surfaces compact boot marker progress alongside raw serial output
- The shipped browser demo now builds with MoonBit's `wasm-gc` backend by default for Alpine boot work
- Browser host input and artifact loading now use a byte-oriented ABI rather than JS builtin string interop

## Prerequisites For Next Milestone

- Resume the post-Linux extension sequence at the next narrow `V` slice
