# Task 0011: Stabilize The Practical RV64 Core

## Background

Before Linux bring-up, the RV64 CPU core should be stable on its own. This stage exists to keep core instruction bugs separate from privileged and MMU bugs.

## Work

- Use this task as the umbrella for practical `RV64` core stabilization after the sign-extension checkpoint
- Carry forward `M`, `C`, `Zicsr`, and `Zifencei` onto the RV64 path
- Add official `RV64` regression plumbing without mixing in MMU, SBI, or platform work

## Subtasks

- [0034 RV64 carry-forward of `C`, `Zicsr`, and `Zifencei`](0034-rv64-carry-forward-of-c-zicsr-zifencei.md)
- [0035 ELF64 loader and RV64 official plumbing](0035-elf64-loader-and-rv64-official-plumbing.md)
- [0036 RV64 official survey and practical-core closure](0036-rv64-official-survey-and-practical-core-closure.md)

## Acceptance Criteria

- RV64 practical-core regressions pass without relying on MMU or SBI
- Integer-core failures can still be isolated from system-integration failures
- Official `rv64ui` / `rv64um` survey coverage exists without broadening CI gating beyond the current RV32 subset

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0010](0010-rv64-transition.md)

## Status

- `done`

## Completion Notes

- The current compressed subset, `Zicsr`, and `Zifencei` now have explicit RV64 carry-forward regressions
- `Runner.load_elf(...)` supports both `ELF32` and `ELF64`
- The official build and survey path now distinguishes RV32 and RV64 artifacts by XLEN-specific build roots
- Curated `rv64ui` and `rv64um` survey rows are present in the manifest while the always-green CI subset remains RV32-only
- The next active task is [Task 0012](0012-s-mode-and-delegation.md)
