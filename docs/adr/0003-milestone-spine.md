# ADR 0003: Use A CPU-Core Checkpoint And A System-Integration Checkpoint

## Context

The project needs milestone boundaries that remain meaningful as the scope grows from a small RV32 emulator toward Linux and browser hosting.

## Decision

Use three major checkpoint meanings in the roadmap:

- `RV32IMC` is the core-completion checkpoint
- `RV32IMC + Zicsr + Zifencei` is the first practical standalone CPU checkpoint
- `Linux boot` is the system-integration checkpoint

Keep `Minimal M-mode` as the transition between CPU and system work, and make the `RV32 Supervisor + Sv32` versus `RV64 transition` decision explicit in the roadmap instead of leaving it implicit.

## Rationale

- The milestones stay understandable even as implementation details change
- Future agents can tell whether a task belongs to CPU work, system work, or post-Linux compatibility work
- The branch point between 32-bit exploration and the general-purpose 64-bit path is documented instead of inferred

## Consequences

- Some roadmap milestones are alternatives rather than strict serial steps
- Linux-related work must be described in platform terms, not just ISA-extension terms
