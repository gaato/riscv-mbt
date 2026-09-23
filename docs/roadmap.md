# Roadmap

## Current Position

- Active milestone: [Milestone 13: Fast, Observable, Networked Linux](milestones/13-fast-observable-networked-linux.md) under [ADR 0011](adr/0011-no-version-tags-and-new-direction.md)
- Current checkpoint: `RV64GC` core, OpenSBI/`virt`-like platform, one-hart and SMP Linux boot, and Alpine rootfs boot natively and in browser Wasm are all in place; the repo builds and tests clean on the pinned MoonBit toolchain
- Next concrete target: Task 0065 (step hot-path de-allocation), then the Milestone 13 slice order
- No version tags; `moon.mod` stays `0.1.0` until a mooncakes release
- Design rule: protect implementation boundaries first, then add instructions
- Milestone semantics:
  - `RV32IMC` = core completion checkpoint
  - `RV32IMC + Zicsr + Zifencei` = first practical standalone CPU checkpoint
  - `Linux boot` = system integration checkpoint
  - `Browser Demo` = delivery checkpoint for a thin browser host over the validated core
  - `Post-Linux compatibility target` = the point where future extension work gets anchored to an explicit software-compatibility contract
  - `Extensions: A, F/D, V, H` = the stage where profile-driven compatibility gaps are closed first and non-profile extension families are then taken in explicit order
  - `Browser Wasm Linux Boot` = the stage where the Linux-capable core is delivered through a Wasm browser host

## Milestones

1. [RV32I](milestones/01-rv32i.md)
2. [RV32IM](milestones/02-rv32im.md)
3. [RV32IMC](milestones/03-rv32imc.md)
4. [RV32IMC + Zicsr + Zifencei](milestones/04-rv32imc-zicsr-zifencei.md)
5. [Minimal M-mode](milestones/05-minimal-m-mode.md)
6. [RV32 Supervisor + Sv32 (optional branch)](milestones/06a-rv32-supervisor-sv32.md)
7. [RV64 transition for the general-purpose path](milestones/06b-rv64-transition.md)
8. [Linux boot platform integration](milestones/07-linux-boot-platform.md)
9. [Post-Linux compatibility target](milestones/08-post-linux-compatibility.md)
10. [Extensions: A, F/D, V, H](milestones/09-extensions-a-fd-v-h.md)
11. [Verification, debug, and performance](milestones/10-verification-debug-performance.md)
12. [Browser Demo](milestones/11-browser-demo.md)
13. [Browser Wasm Linux Boot](milestones/12-browser-wasm-linux-boot.md)
14. [Fast, Observable, Networked Linux](milestones/13-fast-observable-networked-linux.md)

## Dependency Spine

- `RV32I` is the first correctness milestone and unlocks all later CPU work.
- `RV32IM` is the first “usable integer core” checkpoint.
- `RV32IMC` is the “core completion” checkpoint where mixed-width fetch becomes part of the contract.
- `RV32IMC + Zicsr + Zifencei` is the first practical standalone CPU target for system-facing experiments.
- `Minimal M-mode` is the bridge from CPU work into system work.
- After `Minimal M-mode`, the roadmap branches:
  - `RV32 Supervisor + Sv32` is the learning-and-OS-experiment path on 32-bit.
  - `RV64 transition` is the preferred path for general-purpose software compatibility and Linux.
- On the RV64/Linux path, keep the stages separate:
  - RV64 sign-extension and `*W` correctness
  - practical RV64 core stabilization
  - `S`-mode and delegation
  - `Sv39` and `SFENCE.VMA`
  - OpenSBI + `QEMU virt`-like platform bring-up
  - Linux boot ABI and single-hart boot
  - SMP only after single-hart boot is stable
- Linux boot depends on privileged execution, MMU, SBI/boot ABI, and a `QEMU virt`-style platform more than on simply accumulating ISA extensions.
- Browser demo depends on the Linux-capable core staying UI-independent.
- Browser delivery is complete once the thin host exists and the public smoke deploy is live.
- Browser Wasm Linux boot depends on preserving the shared core boundary while adding a Wasm artifact, browser-loadable Linux artifacts, long-run scheduling, and browser serial observability.
- Browser Wasm Linux boot and the tiny Alpine initramfs proof are stable enough that the next usability bottleneck is Linux I/O, not opportunistic ISA growth. RVV backlog work should pause behind full-rootfs I/O unless Linux execution exposes a concrete ISA or privileged-architecture gap.

## Operating Rules

- Repo docs are the source of truth.
- GitHub Issues mirror milestones or task bundles but should never contain stricter details than the repo docs.
- ADRs record decisions that would otherwise force future agents to guess.

## Backlog

Ordered by expected software value. Milestone 13 owns bounded uop / basic-block
caching (its last slice, under the ADR 0009 gates) and browser wall-clock
tuning; the items below are not on the Milestone 13 path.

1. Daemon-style OpenRC service supervision in the Alpine rootfs (the open tail of Task 0062), preceded by the emulator-side process/signal/poll/pipe/timer inspection that task recorded
2. `V` completion: vector floating-point, reductions, `vstart != 0` restart semantics, wider segment forms; then decide whether `V` is advertised to Linux
3. Browser network transport, browser gdb bridge, and porting `virtio-blk` onto the shared `virtio/` package (Milestone 13 tail)
4. `riscv-arch-test` conformance and an RV64 QEMU cross-check path alongside the existing RV32 one
5. Deeper F/D exception-flag and NaN corner-case audits beyond the official `riscv-tests` surface
6. Optional extensions in priority order: `Zba`/`Zbb`/`Zbs`, `Zicbo*`, `Zfh`, `Svnapot`, then `H`
7. PMP and Debug Mode / `Sdtrig`, only if a concrete guest needs them
8. The RV32 supervisor / `Sv32` side branch (Task 0009)
