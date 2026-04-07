# ADR 0004: Protect Implementation Boundaries Before Growing ISA Coverage

## Context

The emulator will evolve through optional branches, RV64 widening, privileged mode, MMU work, and Linux bring-up. If those concerns mix too early, later debugging becomes ambiguous and expensive.

## Decision

Treat fetch, decode, CSR handling, trap flow, and address translation as separate implementation boundaries, and keep RV64 practical-core stabilization separate from Linux platform integration.

## Rationale

- `C` changes fetch alignment behavior
- `Zicsr` and `Zifencei` change system-facing semantics before full privileged mode exists
- RV64 widening introduces sign-extension and `*W` invariants that are easy to hide inside later Linux bugs
- Linux bring-up depends on MMU, SBI, DTB, boot ABI, and platform shape in addition to ISA coverage

## Consequences

- Some roadmap tasks become smaller and more numerous
- Linux-related tasks should be decomposed into delegation, MMU, SBI/platform, boot ABI, and SMP instead of one monolith
