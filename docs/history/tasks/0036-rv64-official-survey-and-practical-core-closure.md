# Task 0036: RV64 Official Survey And Practical-Core Closure

## Background

Once RV64 practical-core behavior and plumbing exist, the milestone should be closed against a curated official survey instead of stopping at handwritten regressions.

## Work

- Add curated `rv64ui` survey rows
- Add curated `rv64um` survey rows including `*W` coverage
- Keep RV64 official coverage survey-only during `0011`
- Close `0011` once the RV64 survey path is green and RV32 gating remains stable

## Acceptance Criteria

- `rv64ui` survey rows pass
- `rv64um` survey rows pass
- Existing RV32 gating remains unchanged
- `0011` can be marked complete and the next task can advance to `0012`

## Related Milestone

- `RV64 transition`

## Dependencies

- [Task 0035](0035-elf64-loader-and-rv64-official-plumbing.md)

## Status

- `done`

## Completion Notes

- Curated `rv64ui` and `rv64um` survey rows are present in the official manifest
- The always-green CI subset remains RV32-only while RV64 coverage stays survey-only
- Practical RV64 core stabilization is complete, so the next mainline task is [Task 0012](0012-s-mode-and-delegation.md)
