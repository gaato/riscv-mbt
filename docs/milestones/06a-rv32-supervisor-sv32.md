# Milestone 06A: RV32 Supervisor + Sv32

## Purpose

Provide an optional 32-bit branch for OS experiments, supervisor-mode learning, and paging work before any RV64 pivot.

## Target Instructions / Features

- Supervisor-mode transitions and delegated traps where needed
- `Sv32` address translation
- Supervisor-facing exception and page-fault behavior

## Non-Goals

- Broad software compatibility
- Linux-first optimization

## Exit Criteria

- Supervisor control-flow tests pass
- `Sv32` translation and fault tests pass
- Docs mark this path as optional rather than the default Linux route

## Required Tests

- Supervisor trap and return tests
- `Sv32` translation and page-fault tests

## Prerequisites For Next Milestone

- None; this path is an optional branch
