# ADR 0012: Reusable Sub-Packages, Extractable To Modules

## Status

Accepted

## Date

2026-09-23

## Context

Milestone 13 needs three pieces that have nothing emulator-specific in them: a
user-mode NAT / TCP-IP stack, a GDB remote serial protocol layer, and a generic
virtio split-virtqueue plus virtio-mmio register model. The owner wants such
pieces to be reusable outside this project, as MoonBit packages and eventually
as separate modules on mooncakes.

The implementing agent (Codex) works inside this repository only and cannot
run `moon`, so the pieces must be developed here first.

## Decision

Build reusable pieces as sub-packages of this module, designed as if they were
already separate modules:

| Piece | Sub-package | Future module |
|---|---|---|
| NAT / TCP-IP stack | `slirp/` (`gaato/riscv_mbt/slirp`, alias `@slirp`) | `gaato/slirp` |
| GDB remote serial protocol | `gdb_rsp/` (`@gdb_rsp`) | `gaato/gdb_rsp` |
| virtio virtqueue + mmio v2 registers | `virtio/` (`@virtio`) | `gaato/virtio` |

Rules for these sub-packages:

- Import only `moonbitlang/core/*`. Never the root package, never
  `moonbitlang/async`.
- Sans-IO: the package performs no I/O. Hosts feed bytes or frames in and poll
  actions or output out. This is what lets native async, browser
  fetch/WebSocket, and unit tests drive the same code.
- Each has its own `README.mbt.md`, its own tests, and a committed
  `pkg.generated.mbti`. `moon check --target wasm-gc` must pass.
- Consumers use only the alias, so extraction changes one import line.

Extraction happens at a checkpoint named in the task doc, after the piece has
a real consumer working end to end. The procedure: create
`~/ghq/github.com/gaato/<name>` with its own `moon.mod` (`version = "0.1.0"`),
`git mv` the package there, develop side by side through an untracked
`moon.work` in this repo (`members = [".", "../<name>"]`; `moon.work` is
gitignored), switch this module's `moon.mod` to the published import, and
`moon publish` before the consuming change lands on `main` so CI resolves it.

The DTB builder stays in `tools/build_minimal_dtb.py`; nothing in the plan
needs DTB generation inside MoonBit.

## Consequences

- The root package grows three imports; `cmd/browser` compiles them for
  `wasm-gc`, which enforces the portability rule continuously.
- The virtio layer is the one piece whose trait boundary (guest memory
  access) is unproven; it stays here until `virtio-net` and, optionally, a
  `virtio-blk` port both use it.
