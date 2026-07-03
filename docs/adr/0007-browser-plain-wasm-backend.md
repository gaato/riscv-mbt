# ADR 0007: Use Plain Wasm For The Browser Host

## Status

Accepted

## Date

2026-07-03

## Context

The browser Linux boot milestone originally used MoonBit's `wasm-gc` backend. That path worked, including Linux early boot in the browser, but it depended on JS builtin string interop:

- `use-js-builtin-string = true`
- imported string constants
- `wasm:js-string` imports
- exported browser functions that accepted MoonBit `String` values from JavaScript

That coupling is avoidable for the browser host. The browser runtime needs byte streams for UART input and Linux artifacts, not general host string interop.

## Decision

Make the shipped browser demo build use MoonBit's plain `wasm` backend.

Keep the browser ABI byte-oriented:

- UART input enters through byte pushes plus an explicit flush
- Linux artifact bytes enter through packed byte calls
- Browser console text remains exposed as codepoint accessors

The `wasm-gc` link section can remain available as a comparison build, but the browser demo build script and generated artifact target plain `wasm`.

## Alternatives Considered

### Keep `wasm-gc`

- Pros: Smaller browser artifact in the current build and direct JS string interop
- Cons: Requires imported string constants and `wasm:js-string` support; keeps artifact transfer tied to strings
- Rejected for the shipped browser host: the browser ABI should be explicit bytes

### Export Raw Wasm Memory For Bulk Copies

- Pros: Could reduce JS-to-Wasm call overhead for large artifacts
- Cons: Requires a stronger memory ownership contract than the current browser boundary exposes
- Deferred: packed byte calls are enough to prove the backend switch while keeping the ABI small

## Consequences

- The active browser artifact has no Wasm imports in the current build
- The browser Wasm file is larger in the observed debug build than the `wasm-gc` artifact
- Artifact transfer is no longer string-based, but still pays JS-to-Wasm call overhead
- Linux boot remains slow; the backend switch did not remove the interpreter/MMU/device-emulation bottleneck
