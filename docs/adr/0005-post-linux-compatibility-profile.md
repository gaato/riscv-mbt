# ADR 0005: Define A Profile-Driven Post-Linux Compatibility Target

## Context

Linux boot is now working, and the browser smoke demo is publicly hosted. The next mainline decision is no longer "which subsystem to bring up next" but "which compatibility target future extension work is supposed to honor".

The repo cannot yet honestly label itself as a complete `RV64G` or `RV64GC` emulator without leaving too much implied behavior outside the current contract. At the same time, continuing without a target would force future extension work to depend on chat memory and ad-hoc decisions.

## Decision

Use a profile-driven post-Linux compatibility target instead of naming the repo after a full ISA shorthand such as `RV64G` or `RV64GC`.

The default compatibility target is:

- `RV64 Linux Profile v1`

This profile means:

- a Linux-capable `RV64` emulator is the baseline
- the current baseline includes:
  - `RV64` integer execution
  - current `M`, `A`, and current `C` coverage
  - `Zicsr` and `Zifencei`
  - `S`-mode, delegation, and `Sv39`
  - OpenSBI plus a virt-like platform
  - Linux boot ABI and SMP follow-through
- the next required compatibility extension family is `F`/`D`
- `V` and `H` are explicitly outside the base profile

## Rationale

- The repo already implements more than a bare integer Linux path, but less than a complete `RV64GC` claim would normally imply.
- A profile label lets the docs describe the software-facing contract directly instead of overloading ISA shorthand.
- This keeps future extension prioritization honest: `F`/`D` is the first compatibility gap to close, not `A`.

## Consequences

- Future extension work should cite `RV64 Linux Profile v1` as the baseline contract.
- Milestone 09 should treat `F`/`D` as the first extension family to land after the compatibility decision.
- If the repo eventually reaches a stronger standard label such as `RV64GC`, that should be recorded by a follow-up ADR instead of being inferred retroactively.
