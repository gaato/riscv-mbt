# gaato/riscv_mbt

MoonBit RISC-V emulator playground.
*** Add File: docs/roadmap.md
# Roadmap

## Current Position

- Active milestone: `RV32I`
- Current checkpoint: docs/agent operating system + bootstrap RV32I subset implemented
- Next concrete target: finish the remaining `RV32I` integer, branch, and memory-width instructions

## Milestones

1. [RV32I](milestones/01-rv32i.md)
2. [RV32IM](milestones/02-rv32im.md)
3. [RV32IMC](milestones/03-rv32imc.md)
4. [RV64I](milestones/04-rv64i.md)
5. [RV64M](milestones/05-rv64m.md)
6. [RV64IMC](milestones/06-rv64imc.md)
7. [RV64I + Zicsr + Trap Basics](milestones/07-rv64i-zicsr-trap.md)
8. [RV64IMA + Zifencei + Privileged Basics](milestones/08-rv64ima-privileged.md)
9. [SV39 + Bus + Devices](milestones/09-sv39-bus-devices.md)
10. [RV64GC Linux Boot](milestones/10-rv64gc-linux-boot.md)
11. [Browser Demo](milestones/11-browser-demo.md)

## Dependency Spine

- `RV32I` is the first correctness milestone and unlocks all later CPU work.
- `RV32IM` and `RV32IMC` complete the 32-bit integer track before widening to `RV64`.
- `RV64I` is the pivot from learning-oriented CPU work to the eventual Linux path.
- Privileged mode, `SV39`, and devices all depend on `RV64I`.
- Linux boot depends on `RV64GC`, privileged features, `SV39`, and `QEMU virt`-like devices.
- Browser demo depends on the Linux-capable core staying UI-independent.

## Operating Rules

- Repo docs are the source of truth.
- GitHub Issues mirror milestones or task bundles but should never contain stricter details than the repo docs.
- ADRs record decisions that would otherwise force future agents to guess.
*** Add File: docs/current.md
# Current State

## Current Milestone

- `RV32I`

## Current Tasks

- [Bootstrap the repo operating system](tasks/0001-bootstrap-operating-system.md) — `done`
- [Implement the RV32I bootstrap subset](tasks/0002-rv32i-bootstrap-subset.md) — `done`
- [Finish remaining RV32I base instruction coverage](tasks/0003-rv32i-complete-base-core.md) — `doing`
- [Introduce riscv-tests for RV32I regression](tasks/0004-riscv-tests-integration.md) — `todo`

## Next Task

- Extend decode and execute coverage for the remaining `RV32I` base instructions, starting with the rest of `OP-IMM`, `OP`, load/store widths, and branch variants.

## Known Blockers

- `qemu-system-riscv64` and a RISC-V cross compiler are not installed locally yet.
- `riscv-tests` are not vendored or wired in yet.

## Read Next

- [Roadmap](roadmap.md)
- [RV32I milestone](milestones/01-rv32i.md)
- [Task 0003](tasks/0003-rv32i-complete-base-core.md)
- [ADR 0001](adr/0001-rv32i-first.md)
*** Add File: docs/milestones/01-rv32i.md
# Milestone 01: RV32I

## Purpose

Establish the first complete, test-driven CPU milestone: a CLI-runnable `RV32I` bare-metal emulator.

## Target Instructions / Features

- Integer register file and `pc`
- Flat RAM
- `fetch/decode/execute`
- U-type: `LUI`, `AUIPC`
- Jumps: `JAL`, `JALR`
- Branches: all `RV32I` base branch instructions
- Loads/stores: `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`
- Integer ALU: `ADD`, `SUB`, shifts, compares, bitwise ops, immediate variants

## Non-Goals

- `M`, `A`, `C`, floating point, CSR, privileged mode, MMU, devices

## Exit Criteria

- Small hand-assembled `RV32I` programs run correctly from the CLI
- Core instruction groups have execute tests
- Decode helpers cover major immediate formats
- Unknown or unsupported instructions trap cleanly

## Required Tests

- Decode tests for I/S/B/U/J immediates
- Execute tests for representative instructions from each instruction group
- Integration tests for small programs that cover register, memory, branch, and jump behavior

## Prerequisites For Next Milestone

- Stable execute semantics for the full base integer ISA
- Enough regression coverage to add `M` without ambiguity
*** Add File: docs/milestones/02-rv32im.md
# Milestone 02: RV32IM

## Purpose

Add integer multiply/divide support on top of a stable `RV32I` core.

## Target Instructions / Features

- `MUL`, `MULH`, `MULHSU`, `MULHU`
- `DIV`, `DIVU`, `REM`, `REMU`
- Early `riscv-tests` integration for integer ISA coverage

## Non-Goals

- Compressed instructions
- 64-bit widening
- Privileged mode

## Exit Criteria

- `RV32I` regressions remain green
- `M` instructions have execute tests and representative integration coverage
- `riscv-tests` start covering the integer core

## Required Tests

- Edge cases around divide by zero and signed overflow
- Regression coverage for mixed `I` + `M` programs

## Prerequisites For Next Milestone

- Stable decode/execute structure that can accept variable-width fetch in `RV32IMC`
*** Add File: docs/milestones/03-rv32imc.md
# Milestone 03: RV32IMC

## Purpose

Introduce compressed instructions after the 32-bit integer core is stable.

## Target Instructions / Features

- 16-bit instruction fetch and length detection
- Compressed decode path and expansion strategy
- `RV32IMC` execution compatibility

## Non-Goals

- 64-bit widening
- Privileged mode

## Exit Criteria

- Mixed 16/32-bit programs run correctly
- `pc` updates remain correct across instruction widths

## Required Tests

- Instruction-length tests
- Integration tests that jump across compressed and non-compressed instructions

## Prerequisites For Next Milestone

- Fetch/decode abstraction clean enough to add `RV64I`
*** Add File: docs/milestones/04-rv64i.md
# Milestone 04: RV64I

## Purpose

Widen the stable `RV32` core to `RV64I` without breaking the 32-bit track.

## Target Instructions / Features

- `XLEN=64`
- 64-bit register semantics
- 64-bit load/store and sign-extension rules
- RV64-specific ALU differences and shift rules

## Non-Goals

- Privileged mode
- Devices and MMU

## Exit Criteria

- Existing RV32 regression remains intact where applicable
- RV64 execute coverage exists for register width and sign-extension edge cases

## Required Tests

- 64-bit immediate and width handling
- `LW` vs `LD` semantics
- Shift mask behavior

## Prerequisites For Next Milestone

- Stable 64-bit integer core
*** Add File: docs/milestones/05-rv64m.md
# Milestone 05: RV64M

## Purpose

Add 64-bit multiply/divide support on top of `RV64I`.

## Target Instructions / Features

- RV64 `M` extension

## Non-Goals

- Compressed instructions
- Privileged mode

## Exit Criteria

- `RV64I` regressions stay green
- RV64 `M` edge cases are covered

## Required Tests

- Signed and unsigned multiply/divide variants
- Overflow and divide-by-zero behavior

## Prerequisites For Next Milestone

- Stable decode/execute structure ready for compressed RV64
*** Add File: docs/milestones/06-rv64imc.md
# Milestone 06: RV64IMC

## Purpose

Reach the first broadly useful 64-bit integer emulator state.

## Target Instructions / Features

- RV64 compressed instruction support
- Stable mixed-width fetch/decode on the 64-bit core

## Non-Goals

- CSR and privileged mode

## Exit Criteria

- `RV64IMC` programs run correctly
- Integer emulator is stable enough to be considered the first general-purpose release

## Required Tests

- Mixed compressed/non-compressed RV64 programs
- Regression on `pc` alignment and jump behavior

## Prerequisites For Next Milestone

- Stable RV64 core to host CSR and trap logic
*** Add File: docs/milestones/07-rv64i-zicsr-trap.md
# Milestone 07: RV64I + Zicsr + Trap Basics

## Purpose

Introduce the minimum control and exception machinery needed for system work.

## Target Instructions / Features

- Core CSR reads/writes
- Trap entry/exit skeleton
- Exception routing basics

## Non-Goals

- Full privileged architecture
- MMU and devices

## Exit Criteria

- CSR read/write tests pass
- Controlled trap flows work in targeted tests

## Required Tests

- CSR mutation tests
- Trap entry and return-state tests

## Prerequisites For Next Milestone

- Enough control-plane behavior to add privileged mode
*** Add File: docs/milestones/08-rv64ima-privileged.md
# Milestone 08: RV64IMA + Zifencei + Privileged Basics

## Purpose

Move from a pure CPU emulator toward a system emulator.

## Target Instructions / Features

- `A`
- `Zifencei`
- `M`/`S` mode basics
- Key privileged CSR set
- Interrupt skeleton

## Non-Goals

- Full Linux boot
- MMU and full device model

## Exit Criteria

- Atomic instruction smoke tests pass
- Privileged transitions and interrupt basics are exercised

## Required Tests

- Atomic read-modify-write tests
- Privilege transition and interrupt routing tests

## Prerequisites For Next Milestone

- Stable privileged execution model
*** Add File: docs/milestones/09-sv39-bus-devices.md
# Milestone 09: SV39 + Bus + Devices

## Purpose

Provide the system substrate needed for Linux-era execution.

## Target Instructions / Features

- `SV39`
- MMIO bus
- UART
- CLINT
- PLIC
- virtio-block
- Device tree
- `QEMU virt`-style memory map

## Non-Goals

- Floating point
- Browser UI

## Exit Criteria

- Page translation tests pass
- Core devices are reachable through the bus
- OpenSBI-facing machine shape is coherent

## Required Tests

- Translation and page-fault tests
- Device access smoke tests

## Prerequisites For Next Milestone

- System model stable enough for OpenSBI and Linux boot
*** Add File: docs/milestones/10-rv64gc-linux-boot.md
# Milestone 10: RV64GC Linux Boot

## Purpose

Use Linux boot as a proof that the system emulator is coherent.

## Target Instructions / Features

- `F` and `D`
- OpenSBI boot path
- Linux kernel + initramfs boot path

## Non-Goals

- Browser UI polish

## Exit Criteria

- Linux emits boot logs through the emulated serial path
- Boot flow is documented and reproducible

## Required Tests

- Targeted FP smoke tests
- Boot acceptance script or documented manual path

## Prerequisites For Next Milestone

- UI-independent core ready to be hosted in the browser
*** Add File: docs/milestones/11-browser-demo.md
# Milestone 11: Browser Demo

## Purpose

Expose the emulator through a browser UI without entangling the core with presentation code.

## Target Instructions / Features

- JS/Wasm target
- Serial console view
- Keyboard input
- Minimal boot controls

## Non-Goals

- Rich IDE-like front-end

## Exit Criteria

- Browser-hosted emulator can boot the prepared demo image
- UI remains a thin host over the shared core

## Required Tests

- Smoke test for browser entrypoint
- Manual verification checklist for serial interaction

## Prerequisites For Next Milestone

- None
*** Add File: docs/tasks/0001-bootstrap-operating-system.md
# Task 0001: Bootstrap The Repo Operating System

## Background

The project needs a repo-local source of truth that both humans and AI agents can follow without re-deriving context from chat history.

## Work

- Rewrite `README.md` around current state and next milestone
- Add `docs/roadmap.md`, `docs/current.md`, milestone docs, task docs, and ADRs
- Add `AGENTS.md`
- Add GitHub issue templates for milestone and task mirroring

## Acceptance Criteria

- A new agent can read `README.md` and `docs/current.md` and know what to do next
- Milestone, task, and ADR structure exists in-repo

## Related Milestone

- `RV32I`

## Dependencies

- None

## Status

- `done`
*** Add File: docs/tasks/0002-rv32i-bootstrap-subset.md
# Task 0002: Implement The RV32I Bootstrap Subset

## Background

The first code checkpoint should prove that the MoonBit project shape, public interfaces, and test harness can support real CPU work.

## Work

- Create `CpuState`, `Bus`, `Instruction`, `StepResult`, `Runner`, and `MachineConfig`
- Support a bootstrap subset of `RV32I`
- Add decode, execute, and integration tests
- Wire a simple CLI demo

## Acceptance Criteria

- `moon test` passes
- A small hand-assembled program can run through the CLI demo
- Unsupported instructions trap instead of silently misbehaving

## Related Milestone

- `RV32I`

## Dependencies

- [Task 0001](0001-bootstrap-operating-system.md)

## Status

- `done`
*** Add File: docs/tasks/0003-rv32i-complete-base-core.md
# Task 0003: Complete The Remaining RV32I Base Core

## Background

The repo now has a bootstrap subset of `RV32I`, but the first milestone is the full base integer ISA.

## Work

- Add the remaining base branch variants
- Add the remaining base integer ALU and immediate instructions
- Add byte and halfword loads/stores with correct extension behavior
- Expand execute and integration tests

## Acceptance Criteria

- `RV32I` milestone doc exit criteria are satisfied
- Core instruction groups have representative tests
- Current docs reflect milestone completion truthfully

## Related Milestone

- `RV32I`

## Dependencies

- [Task 0002](0002-rv32i-bootstrap-subset.md)

## Status

- `doing`
*** Add File: docs/tasks/0004-riscv-tests-integration.md
# Task 0004: Integrate riscv-tests For RV32I

## Background

Once the base integer ISA is in place, regression should move beyond only hand-authored tests.

## Work

- Vendor or fetch `riscv-tests`
- Add a repeatable way to build or import relevant RV32 test binaries
- Add a test runner path that compares signatures or pass/fail conventions

## Acceptance Criteria

- A documented subset of `riscv-tests` runs in CI/local dev
- Failures are actionable enough to use during TDD

## Related Milestone

- `RV32IM`

## Dependencies

- [Task 0003](0003-rv32i-complete-base-core.md)

## Status

- `todo`
*** Add File: docs/adr/0001-rv32i-first.md
# ADR 0001: Start From RV32I

## Context

The long-term goal includes `RV64GC`, Linux boot, and browser hosting, but the project is also intended to be a general-purpose emulator and a learning vehicle.

## Decision

Start from `RV32I` as the first complete milestone, then expand through ISA milestones before switching to the 64-bit and system path.

## Rationale

- `RV32I` keeps the first CPU milestone small enough for tight TDD loops
- The first milestone remains useful even outside the Linux path
- It creates a stable base for later `RV64` widening

## Consequences

- Some widening work will be deferred to the `RV64I` milestone
- Early design should avoid hard-coding choices that make `XLEN` evolution painful
*** Add File: docs/adr/0002-repo-markdown-source-of-truth.md
# ADR 0002: Repo Markdown Is The Source Of Truth

## Context

The project will be worked on by humans plus coding agents across many sessions. Chat history alone is too fragile to preserve intent and state.

## Decision

Keep milestone, task, and current-state information in repo-local Markdown. GitHub Issues mirror that information for collaboration but do not replace it.

## Rationale

- Local docs are always available to coding agents
- Repo diffs show when scope or execution state changes
- Agents can rehydrate context without requiring API calls or issue sync

## Consequences

- Docs must be updated with code changes
- GitHub Issues should link back to the canonical repo docs
*** Add File: moon.mod.json
{
  "name": "gaato/riscv_mbt",
  "version": "0.1.0",
  "readme": "README.mbt.md",
  "repository": "https://github.com/gaato/riscv-mbt",
  "license": "Apache-2.0",
  "keywords": [
    "riscv",
    "emulator",
    "moonbit"
  ],
  "description": "A MoonBit RISC-V emulator project that grows milestone by milestone."
}
