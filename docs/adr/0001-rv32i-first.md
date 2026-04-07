# ADR 0001: Start From RV32I

## Context

The long-term goal includes `RV64GC`, Linux boot, and browser hosting, but the project is also intended to be a general-purpose emulator and a learning vehicle.

## Decision

Start from `RV32I` as the first complete milestone, then expand through ISA milestones before switching to the 64-bit and system path.

## Rationale

- `RV32I` keeps the first CPU milestone small enough for tight TDD loops
- The first milestone remains useful even outside the Linux path
- It creates a stable base for later `RV64` widening

## Consequences

- Some widening work will be deferred to the `RV64I` milestone
- Early design should avoid hard-coding choices that make `XLEN` evolution painful
