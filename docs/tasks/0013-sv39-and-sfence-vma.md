# Task 0013: Add Sv39 And SFENCE.VMA

## Background

The largest Linux-adjacent correctness cliff is virtual memory, especially the interaction of `satp`, page-table updates, and `SFENCE.VMA`.

## Work

- Implement `Sv39`
- Model `satp` and page-table-walk behavior cleanly
- Add `SFENCE.VMA`, initially allowing a simple global-flush implementation
- Add focused tests for page translation and page-fault behavior

## Acceptance Criteria

- `satp` updates and `SFENCE.VMA` interactions are documented and tested
- Page-table update ordering bugs are catchable without running Linux

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0012](0012-s-mode-and-delegation.md)

## Status

- `todo`
