# Implementation Notes

This document captures the practical cautions that matter across milestones, especially on the path from `RV64` transition to Linux boot.

## Global Rules

- Prefer stable implementation boundaries over fast instruction-count growth.
- Keep fetch, decode, CSR handling, trap flow, and address translation separable.
- Treat Linux boot as a platform-integration problem, not as proof that “enough instructions” exist.
- Keep one-hart bring-up as the baseline; add SMP only after single-hart boot is stable.
- For MoonBit runtime and IO APIs, prefer MoonBit official docs and Context7 over memory when choosing async or native-backend behavior.

## By Stage

### RV32I

- Prioritize `pc` updates, exception behavior, sign extension, and immediate decoding over raw instruction count.
- Keep branch and jump behavior precise enough that instruction-address-misalignment handling does not become ad-hoc later.
- Get `riscv-tests` and eventually architectural tests into the loop early.

### RV32IM

- Pay special attention to `DIV`/`REM` corner cases, especially divide-by-zero and signed overflow behavior.

### RV32IMC

- Treat `C` as a fetch/decode and exception-model change, not just as more opcodes.
- Avoid a fetch implementation that must be thrown away when `IALIGN` changes.

### RV32IMC + Zicsr + Zifencei

- Do not model CSR state as “just an array” without thinking about masked, rounded, or reserved behavior.
- Treat `FENCE.I` as the instruction-visibility boundary for the current hart, not as a vague cache-flush placeholder.

### Minimal M-mode

- Make trap entry and trap return precise from the beginning.
- Keep later delegation in mind so `medeleg` and `mideleg` can arrive cleanly.

### RV64 Transition

- RV64 is not just wider RV32. Preserve the sign-extension invariant for 32-bit values held in 64-bit registers.
- Validate `*W` instructions and width-sensitive behavior independently from Linux bring-up.

### Practical RV64 Core

- Stabilize `RV64I/M/C + Zicsr + Zifencei` before mixing in MMU and SBI problems.
- Keep integer-core debugging separate from system-integration debugging.

### S-mode And Delegation

- Do not leave all trap routing effectively M-mode-only for too long.
- Make `stvec`, `sepc`, `scause`, `stval`, and delegation paths independently testable.

### Sv39

- Treat `satp`, page-table updates, and `SFENCE.VMA` as a single correctness surface.
- A simple global flush is acceptable at first, but missing the fence semantics entirely is not.

### OpenSBI + Virt-Like Platform

- Prefer OpenSBI and a `QEMU virt`-like board shape to a bespoke platform during early Linux bring-up.
- Prioritize UART, timer, interrupt plumbing, and DTB visibility so failures are observable.

### Linux Boot ABI

- Separate “MMU works” from “Linux sees the right initial machine state”.
- Keep `a0`, `a1`, `satp = 0`, and image-placement assumptions explicit and documented.

### SMP

- Add multiple harts only after one-hart boot is stable.
- Expect SMP to couple interrupts, timers, atomics, hart lifecycle, and TLB behavior.

## RV64 To Linux Boot Spine

1. Establish RV64 sign-extension invariants and `*W` correctness.
2. Stabilize the practical RV64 core.
3. Add `S`-mode and delegation.
4. Add `Sv39` and `SFENCE.VMA`.
5. Integrate OpenSBI and a `virt`-like platform.
6. Meet the Linux boot ABI on one hart.
7. Add SMP only after single-hart boot is reliable.

## Verification Priorities

- Use unit tests for decode and execute semantics first.
- Add `riscv-tests` as early as practical.
- Add architectural conformance tests before trusting post-Linux extension work.
- Improve traceability and debug support before chasing late-stage performance wins.

## `riscv-tests` Policy

- Treat upstream `riscv-tests` sources as authoritative for ISA regression.
- Keep handwritten MoonBit tests focused on fast local diagnosis: decode, single-step execute behavior, and small integration programs.
- Prefer official GNU-toolchain and `env/p` execution paths over custom adapters.
- Prefer file-based official ELF loading over embedding large generated blobs into MoonBit source.
- For native async tests, read official ELF files through `moonbitlang/async/fs` and pin the native C compiler explicitly when the platform default linker is unreliable.
- Keep regression in two layers:
  - `gating`: tests expected to pass and stay green in normal CI
  - `survey`: broader upstream coverage that may be expected to fail while features are still missing
- Prefer adding metadata and better classification over inventing more custom tests.
- Build upstream `*-p-*` binaries early even before the current emulator can execute the full privileged startup path.
- If a temporary adapter is ever introduced, keep it explicitly disposable and never let it become the source of truth.

## Refactor Checkpoints

These are the recommended refactors to do immediately before specific milestones. The goal is to keep each milestone focused on its new behavior instead of mixing feature work with emergency cleanup.

### Before `riscv-tests` Integration

- Avoid a large refactor first. Use the current core to learn where conformance tests apply pressure.
- Prefer small test-harness improvements over core-structure changes.

### Before `RV32IM`

- Split the growing execute path into private helpers for ALU, branch, load, and store behavior.
- Keep the public surface stable, but stop growing one giant `Runner::step` match.
- The immediate goal is to make `M` extension work feel like adding one new execution family, not editing unrelated integer paths.

### Before `RV32IMC`

- Refactor instruction fetch so it is no longer hard-coded to `pc + 4`.
- Introduce an internal fetch result that can carry both the raw instruction bits and the instruction length.
- Add `fetch16` and `fetch32`-style helpers even if only 32-bit instructions exist at that moment.
- Treat this as preparation for `IALIGN=16`, mixed-width streams, and compressed-instruction exception behavior.

### Before `RV32IMC + Zicsr + Zifencei`

- Give CSR state a dedicated home instead of keeping all future machine state implicit.
- Add a `CsrFile`-like abstraction with explicit read and write entry points.
- Do not model CSR state as an unstructured array if that would make WARL, WPRI, or masked writes awkward later.
- Keep `FENCE.I` preparation conceptually separate from cache implementation details; the important boundary is instruction visibility to the current hart.

### Before `Minimal M-mode`

- Replace stringly-typed traps with structured trap data.
- Introduce trap cause, trap metadata, and privilege-mode concepts before trap entry/return logic grows.
- Make `TrapInfo`-style data rich enough for `mepc`, `mcause`, and later `mtval`/delegation work.

### Before `RV64 Transition`

- Move XLEN-sensitive behavior behind helpers instead of spreading width rules through the whole executor.
- Centralize sign extension, shift masking, load extension, and `*W` result shaping.
- Keep RV64 widening work separate from MMU, SBI, and Linux-platform work.
- The key invariant is that 32-bit values held in 64-bit registers remain sign-extended.

### Before `S-mode` And `Sv39`

- Separate address translation concerns from physical memory access.
- Do not evolve the RAM-only `Bus` directly into a full MMU by accretion.
- Prepare for a structure closer to translator -> physical bus -> RAM/devices.
- This keeps `satp`, page-table walking, and MMIO from becoming one tangled subsystem.

### Before `OpenSBI + Virt-Like Platform`

- Expand machine configuration so platform assumptions are explicit.
- Keep RAM layout, entry point, board shape, and attached devices in configuration rather than hard-coded behavior.
- The goal is to make early Linux bring-up observable and reproducible on a fixed platform model.

### Test Harness Refactors

- Move instruction encoding helpers into a reusable test-support layer before `C` and `RV64` increase test variety.
- Add helpers for runner setup, stepping multiple instructions, and asserting register or memory state.
- Keep decode tests, single-step execute tests, and small-program integration tests clearly separated even as the suite grows.
