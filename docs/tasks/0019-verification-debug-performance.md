# Task 0019: Strengthen Verification, Debug, And Performance

## Background

Past Linux boot, project maturity depends more on observability and regression resistance than on raw feature count.

## Work

- Integrate `riscv-tests` more deeply
- Add `riscv-arch-test` or equivalent architectural conformance coverage
- Add trace and debug hooks, potentially including gdb-oriented support
- Start performance measurement and regression tracking

## Acceptance Criteria

- Regressions are caught by more than ad-hoc integration tests
- Debug and trace facilities make failures inspectable
- Performance changes can be measured intentionally

## Related Milestone

- `Verification, debug, and performance`

## Dependencies

- [Task 0017](../history/tasks/0017-post-linux-compatibility.md)

## Status

- `done`

## Closure Note (2026-09-23)

Absorbed by [Milestone 13](../milestones/13-fast-observable-networked-linux.md)
under [ADR 0011](../adr/0011-no-version-tags-and-new-direction.md): the GDB
stub is Tasks 0067 to 0069, performance measurement is the ADR 0011 protocol,
and `riscv-arch-test` stays in the roadmap backlog.
