# Task 0025: Add Minimal `env/p` Support

## Background

Official `rv32ui-p-*` binaries use the upstream privileged startup path. The
current emulator does not yet provide the minimal CSR, trap, and return
behavior needed to survive that startup sequence.

## Work

- Implement the minimum CSR surface needed by upstream `env/p`
- Replace stringly-typed traps with structured trap information
- Add minimal machine-mode trap entry and `mret`
- Keep the scope narrow: enough to execute official test startup, not a full
  privileged architecture implementation

## Acceptance Criteria

- The emulator can execute the startup path of at least one official
  `rv32ui-p-*` test far enough to reach the test body
- Missing privileged behavior fails in identifiable, structured ways
- The resulting implementation still points cleanly toward [Task 0008](0008-minimal-m-mode.md)

## Notes

- The current repo now has the minimum `env/p` substrate in the core:
  structured traps, basic CSR ops, `ecall`, `mret`, privilege transitions, and
  trap-vector entry.
- The next step is to use that substrate against real official
  `rv32ui-p-*` binaries in [Task 0026](0026-official-rv32ui-runner.md).

## Related Milestone

- `RV32IM`

## Dependencies

- [Task 0004](0004-riscv-tests-integration.md)
- [Task 0024](0024-official-riscv-tests-loader.md)

## Status

- `done`
