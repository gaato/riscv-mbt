# Task 0007: Add Zicsr And Zifencei

## Background

`RV32IMC` is a strong CPU milestone, but the first practical standalone target for system-facing experiments is `RV32IMC + Zicsr + Zifencei`.

## Work

- Add the six CSR access instructions from `Zicsr`
- Add `FENCE.I` semantics from `Zifencei`
- Define the minimum CSR surface needed before privileged mode

## Acceptance Criteria

- CSR instruction tests pass
- Self-modifying-code or fence-sensitive micro-tests demonstrate `FENCE.I` behavior
- Docs clearly mark this stage as the first practical standalone CPU target

## Related Milestone

- `RV32IMC + Zicsr + Zifencei`

## Dependencies

- [Task 0006](0006-rv32imc.md)

## Status

- `todo`
