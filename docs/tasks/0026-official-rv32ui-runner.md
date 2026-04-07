# Task 0026: Run An Official `rv32ui-p-*` Subset

## Background

Once the loader and minimal `env/p` substrate exist, the next shortest path is
to run a small official `rv32ui-p-*` subset end-to-end and classify failures.

## Work

- Add a runner path for official `rv32ui-p-*` binaries
- Start with a small, explicit subset such as `add`, `addi`, `beq`, `jal`, `lw`, `sw`
- Record pass/fail using upstream-compatible mechanisms such as `tohost`
- Distinguish `expected fail`, `unexpected fail`, and `pass`

## Acceptance Criteria

- A documented official `rv32ui-p-*` subset runs locally
- Failures are attributed to either missing features or actual regressions
- The repo can point to a concrete list of official tests that are green today

## Green Today

- `rv32ui-p-add`
- `rv32ui-p-addi`
- `rv32ui-p-beq`
- `rv32ui-p-bltu`
- `rv32ui-p-lb`
- `rv32ui-p-lhu`
- `rv32ui-p-sw`
- `rv32ui-p-jal`
- `rv32ui-p-jalr`
- `rv32ui-p-lui`
- `rv32ui-p-auipc`

## Related Milestone

- `RV32IM`

## Dependencies

- [Task 0004](0004-riscv-tests-integration.md)
- [Task 0024](0024-official-riscv-tests-loader.md)
- [Task 0025](0025-minimal-env-p-support.md)

## Status

- `done`
