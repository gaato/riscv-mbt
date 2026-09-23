# Current State

## Current Milestone

- [Milestone 13: Fast, Observable, Networked Linux](milestones/13-fast-observable-networked-linux.md) under [ADR 0011](adr/0011-no-version-tags-and-new-direction.md)
- Three tracks: Linux execution-path performance, a GDB remote stub, and `virtio-net` plus a MoonBit user-mode NAT stack
- Reusable pieces are built as sub-packages designed for extraction ([ADR 0012](adr/0012-reusable-subpackages-and-modules.md))
- No version tags; `moon.mod` stays `0.1.0` until a mooncakes release
- Completed task records (0001 to 0063) live in [history/tasks](history/tasks); the 2026-07 narrative is in [history/2026-07-rv64gc-hardening-notes.md](history/2026-07-rv64gc-hardening-notes.md)

## Open Tasks

- [De-allocate the step hot path](tasks/0065-step-hot-path-deallocation.md) — `done`
- [Word-addressed RAM backing store](tasks/0066-word-addressed-ram.md) — `doing`
- [Optional RV32 supervisor + Sv32 path](tasks/0009-rv32-supervisor-sv32.md) — `todo` (side branch, not on the milestone path)

## Next Task

- Task 0066. Claude writes the task doc, Codex implements, Claude validates with the protocol in ADR 0011.
- The full slice order is in Milestone 13.

## Toolchain Contract

- MoonBit is pinned in `moonbit-version` (installed locally through `moonup`); CI installs exactly that version.
- `moon.mod` dependency versions move with the toolchain pin. `moonbitlang/async` is only used by the native host commands and tests, not by the emulator core or the reusable sub-packages.
- The validation sequence is `moon check`, `moon test`, `moon fmt`, `moon info --target native`, and `git diff --check`; all must be clean before a commit. Root-package changes also run `./scripts/build-browser-demo.sh`.

## Known Blockers

- Local `moon test` expects official `riscv-tests` ELF artifacts under `_build/riscv-tests-src/isa` and `_build/riscv-tests-src-rv64/isa`; run `./scripts/build-riscv-tests-official.sh` (or the podman variant, which is the only path on hosts without a `riscv64-elf-gcc`) first.
- The Alpine rootfs builder tracks `latest-stable`, so a rebuild picks up whatever kernel and packages Alpine ships that day; the checked-in probes were last validated against the artifacts recorded in Task 0061 and Task 0062.
- The Alpine kernel ships as `vmlinuz` plus `System.map`, with no `vmlinux` symbols; gdb breakpoints in the kernel are set by address from `System.map`.
- The official QEMU cross-check path is RV32-only.
- Debug Mode / `Sdtrig` and PMP are deliberately not implemented; guests that probe them see the documented trap or zero behavior.

## Read Next

- [Roadmap](roadmap.md)
- [ADR 0011](adr/0011-no-version-tags-and-new-direction.md)
- [Milestone 13](milestones/13-fast-observable-networked-linux.md)
- [Implementation Notes](guides/implementation-notes.md)
