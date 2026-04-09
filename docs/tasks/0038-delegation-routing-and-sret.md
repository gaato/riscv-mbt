# Task 0038: Delegation Routing And `SRET`

## Background

Once the supervisor trap surface exists, delegated exception routing and supervisor trap return should become explicit before MMU work deepens.

## Work

- Use `medeleg` and `mideleg` for trap-routing decisions
- Route delegated exceptions into supervisor trap state instead of defaulting everything to M-mode
- Add `SRET`
- Model the minimum `sstatus` trap-return fields needed for delegated exception flow

## Acceptance Criteria

- Delegated exceptions update `sepc`, `scause`, and `stval`
- Non-delegated exceptions continue to update machine trap state
- `SRET` restores privilege and `sstatus` trap-return fields correctly

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0037](0037-supervisor-csr-surface-and-trap-entry.md)

## Status

- `todo`
