# Roadmap

## Current Position

- Active milestone: `Linux boot platform integration`
- Current checkpoint: practical RV64 core stabilization is complete, including official RV64 survey plumbing
- Next concrete target: add `S`-mode and delegation before MMU work begins
- Design rule: protect implementation boundaries first, then add instructions
- Milestone semantics:
  - `RV32IMC` = core completion checkpoint
  - `RV32IMC + Zicsr + Zifencei` = first practical standalone CPU checkpoint
  - `Linux boot` = system integration checkpoint

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
- Deployment should be phased:
  - decide the hosting target early
  - add the first public deploy when a browser smoke demo exists
  - enable per-branch or per-PR preview deploys when the browser demo becomes an active development surface

## Operating Rules

- Repo docs are the source of truth.
- GitHub Issues mirror milestones or task bundles but should never contain stricter details than the repo docs.
- ADRs record decisions that would otherwise force future agents to guess.
