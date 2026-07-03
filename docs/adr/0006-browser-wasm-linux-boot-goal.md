# ADR 0006: Make Browser Wasm Linux Boot The Active Goal

## Status

Accepted

## Date

2026-07-03

## Context

The emulator core already has a non-browser Linux boot path, and the browser milestone already delivered a public smoke demo. That browser demo is currently JS-target and intentionally small: it proves that the shared core can be hosted in a browser, but it does not run Linux.

The new project goal is to run Linux in the browser through the MoonBit Wasm target. This changes the active work from post-Linux extension growth to browser delivery of the Linux-capable core.

## Decision

Make `Browser Wasm Linux Boot` the active mainline milestone.

The work will alternate implementation and refactor slices:

1. implementation: Wasm browser smoke host
2. refactor: browser runtime boundary
3. implementation: browser Linux artifact loader
4. refactor: browser long-run scheduling, memory, and serial behavior
5. implementation: browser one-hart Linux boot
6. refactor: browser Linux observability and verification

The browser host remains a thin product layer over the shared emulator core. Native Linux boot tests remain the source of truth for emulator boot semantics.

## Alternatives Considered

### Continue Post-Linux `V` Work First

- Pros: Keeps following the existing `RV64 Linux Profile v1` compatibility path
- Cons: Delays the newly selected browser Linux delivery goal
- Rejected: The active goal has changed to browser Wasm Linux boot

### Port Linux Boot Directly Into The Existing JS Browser Host

- Pros: Smallest immediate change to the deployed smoke demo
- Cons: Conflicts with the explicit Wasm target goal and risks accumulating browser/runtime assumptions in the JS host
- Rejected: The browser Linux target should start from Wasm

### Build A Separate Browser-Only Emulator Path

- Pros: Could optimize aggressively for browser constraints
- Cons: Forks behavior from the validated native core and weakens existing test evidence
- Rejected: The repo rule is to keep the browser host thin over the shared core

## Consequences

- While this decision was active, `docs/current.md` pointed to the Wasm browser Linux boot path as the current milestone
- The `V` extension work was intentionally deferred while browser Wasm Linux boot was active, because the remaining `0048` slice was not required for Linux early boot
- Browser build, artifact loading, scheduling, and observability need explicit task boundaries before claiming Linux-in-browser support

## Outcome

Browser Wasm Linux boot is complete as of 2026-07-03. `docs/current.md` now resumes the post-Linux extension sequence at `0048`.
