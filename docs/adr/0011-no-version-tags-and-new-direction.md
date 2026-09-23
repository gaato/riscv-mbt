# ADR 0011: No Version Tags Yet, And The Next Direction

## Status

Accepted. Supersedes the release/tag framing of
[ADR 0010](0010-v1-completion-boundary.md); the completion gate ADR 0010
describes stays valid as a historical record of what was proven by 2026-09-23.

## Date

2026-09-23

## Context

ADR 0010 defined a `v1.0` boundary and `docs/current.md` said the next step was
to tag `v1.0.0`. The owner rejected that: nothing here defines what a release
means to a user, and a version is only meaningful once the module is published
to mooncakes. The owner also observed that the volume of agent-written task
docs and ADRs had become noise rather than context.

The emulator itself is at a natural stopping point: `RV64GC` gated by the
official `riscv-tests`, OpenSBI plus a `virt`-like platform booting Linux and
an Alpine rootfs natively and in browser Wasm. What is missing is not ISA
coverage but speed, observability, and network I/O.

## Decision

1. No git version tags. `moon.mod` stays at `0.1.0`, and that becomes the
   first published version if and when the module goes to mooncakes.
2. The next direction is [Milestone 13](../milestones/13-fast-observable-networked-linux.md):
   a fast, observable, network-connected Linux environment, in three tracks:
   - performance of the Linux execution path (native and browser `wasm-gc`)
   - a GDB remote serial protocol stub so `gdb` can attach to the guest
   - a `virtio-net` device plus a user-mode NAT stack written in MoonBit
3. Docs are de-noised:
   - completed task docs move to `docs/history/tasks/` and `docs/current.md`
     lists only open tasks
   - task docs are the implementation spec handed to the implementing agent
     and are kept short
   - new ADRs are written only for cross-cutting decisions; per-feature design
     lives in the task doc
4. Performance slices are accepted or reverted by a fixed protocol:
   - native: `moon bench` three times, compare means; the noise band is about
     3 %
   - browser: the Alpine interactive smoke three times, compare the median
     wall time and guest steps per second at the shell-response point
   - keep a slice only if at least one target improves (native target bench
     by 3 % or more, or browser median by 3 % or more) and the other target
     does not regress beyond its noise band (about 3 % native, 2 % browser);
     a single run is never a decision
   - benches build their runners outside the timed closure (Task 0066 found
     the 128 MB RAM allocation dominating every earlier memory bench number)
   - a pure performance refactor satisfies the failing-test-first rule with a
     characterization test committed before the change plus tests for any new
     internal API

## Consequences

- `docs/current.md`, `docs/roadmap.md`, and `README.md` drop the `v1.0`
  language.
- Task 0019 (verification, debug, performance) is absorbed by Milestone 13.
- Reusable pieces built for this direction follow
  [ADR 0012](0012-reusable-subpackages-and-modules.md).
