# Task 0004: Integrate riscv-tests For RV32I

## Background

Once the base integer ISA is in place, regression should move beyond only hand-authored tests.
The repo can already build official `rv32ui-p-*` style binaries with the GNU
toolchain, but the emulator does not yet execute the upstream privileged
startup path.

## Work

- Fetch upstream `riscv-tests` as the authoritative test source
- Add a repeatable way to build relevant official RV32 test binaries
- Add a runner path for official binaries that compares pass/fail conventions or signatures
- Separate always-green `gating` coverage from broader `survey` coverage once official execution is possible
- Keep an upstream-compatible build path available even before the current emulator can execute all official binaries
- Make that official build path reproducible in a containerized environment
- Close the execution gap: CSR/trap/return support, privileged startup behavior, and correct image placement for official binaries

## Shortest Path

1. [Load official binaries at their linked addresses](0024-official-riscv-tests-loader.md)
2. [Add the minimum privileged substrate needed for `env/p`](0025-minimal-env-p-support.md)
3. [Run a small official `rv32ui-p-*` subset end-to-end](0026-official-rv32ui-runner.md)
4. [Cross-check the subset in `qemu-system-riscv32`](0027-qemu-cross-check-official-rv32ui.md)

This order is intentionally narrower than full privileged support. The goal is
to make one official `rv32ui-p-*` path real before broadening coverage.

## Acceptance Criteria

- A documented official subset of `riscv-tests` runs in CI/local dev
- Failures are actionable enough to use during TDD
- The repo makes it clear that upstream `riscv-tests` are the source of truth and no adapter layer is required for normal development

## Related Milestone

- `RV32IM`

## Dependencies

- [Task 0003](0003-rv32i-complete-base-core.md)

## Status

- `done`
