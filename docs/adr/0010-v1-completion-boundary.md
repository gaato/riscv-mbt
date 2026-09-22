# ADR 0010: Define The v1.0 Completion Boundary

## Status

Accepted

## Date

2026-09-23

## Context

The repo has grown milestone by milestone without ever stating what "finished"
means. By 2026-07 it had an `RV64GC` core with official `riscv-tests` gating,
OpenSBI plus a `virt`-like platform, one-hart and SMP Linux boot, an Alpine
rootfs booting natively and in browser Wasm, and a partial `V` implementation.
The active task, 0063, is an open-ended spec-compliance audit, and three older
tasks (0048, 0058, 0062) were still `doing`.

Work then paused for roughly eleven weeks. In that time the ecosystem moved:

- MoonBit `0.10.14` no longer compiles `moonbitlang/async@0.16.8`, which this
  repo imported; `moon check` failed on a clean checkout.
- MoonBit added the `test_unqualified_package` lint, which flagged every
  implicitly imported symbol in the blackbox test files.
- `moon fmt` and `moon.pkg` conventions changed (`pkgtype`, trailing commas).
- Nearly 600 local commits on `main` had never been pushed, so CI and the
  public GitHub Pages demo still reflected the 2026-04 state.

Without a stated boundary, every one of the remaining `doing` tasks can absorb
unbounded effort, and "done" keeps receding.

## Decision

`v1.0` is defined as the following, and nothing more:

1. **Baseline ISA**: `RV64IMAFDC_Zicsr_Zifencei` (`RV64GC`) is implemented
   against the RISC-V unprivileged and privileged specifications. The
   mechanical completion gate is the official `riscv-tests` manifest: every
   locally buildable `rv64ui`, `rv64um`, `rv64ua`, `rv64uc`, `rv64uf`,
   `rv64ud` row and every applicable `rv64mi` / `rv64si` row is `gating`.
   Rows that require features the emulator deliberately omits (Debug Mode /
   `Sdtrig` triggers, PMP) are listed as inapplicable in the manifest comments
   and in Task 0063, not silently dropped.
2. **Platform**: OpenSBI on a `QEMU virt`-like platform boots Linux on one hart
   and with SMP natively, and an Alpine rootfs reaches userspace natively and
   in browser Wasm. The public demo at `https://gaato.github.io/riscv-mbt/`
   is built from `main` by CI.
3. **Build health**: `moon check`, `moon test`, `moon fmt`, `moon info`, and
   `git diff --check` are clean on the toolchain pinned in `moonbit-version`,
   and CI installs exactly that version.
4. **Docs**: `docs/current.md` is short and true, every task is `done` or
   explicitly deferred with a reason, and the deferred backlog lives in
   `docs/roadmap.md`.

Explicitly **outside** `v1.0`:

- `V`: the partial implementation stays in the tree as an experimental,
  survey-only extension. Vector FP, reductions, and `vstart` restart are backlog.
- `H`, `Zb*`, `Zfh`, `Zicbo*`, `Svnapot`, and other optional extensions.
- Debug Mode, `Sdtrig`, and PMP.
- The RV32 supervisor / `Sv32` side branch (Task 0009).
- `riscv-arch-test` conformance and an RV64 QEMU cross-check path.
- Daemon-style OpenRC service supervision inside the Alpine rootfs
  (the open tail of Task 0062).
- Further F/D exception-flag and NaN corner-case audits beyond the official
  `riscv-tests` surface.

Task state changes made under this decision:

- 0063 closes when the `rv64mi` / `rv64si` gate lands.
- 0058 and 0062 close on the scope they proved; their remaining tails move to
  the post-`v1.0` backlog.
- 0048 closes on its acceptance criteria; the further `V` backlog is post-`v1.0` work.

## Alternatives Considered

### Keep Auditing Until Every Spec Corner Is Covered

- Pros: Highest possible fidelity
- Cons: No mechanical stopping rule; the audit has already consumed hundreds of
  commits with no closure condition
- Rejected: `v1.0` needs a gate that a machine can check

### Finish `V` Before Declaring `v1.0`

- Pros: Matches the original milestone 09 ordering
- Cons: Linux and Alpine do not require `V`; the remaining `V` work (vector
  FP, reductions, `vstart` restart) is larger than everything else on this list
- Rejected: `V` was already documented as optional backlog behind the
  `RV64GC` closure

### Declare `v1.0` Immediately Without The Privileged Gate

- Pros: Fastest
- Cons: The largest open audit item in Task 0063 is CSR/privileged behavior,
  and `rv64mi` / `rv64si` are the official tests for exactly that; leaving them
  out would make the gate cover only the easy half
- Rejected: The privileged suites are locally buildable, so the existing rule
  ("promote every buildable row") already requires them

## Consequences

- `docs/current.md` shrinks to current milestone, open tasks, next task, and
  blockers; the 2026-07 progress narrative moves to `docs/history/`.
- The `RV64GC` source-completeness gate in `rv32ui_gating_test.mbt` grows to
  cover the applicable `rv64mi` / `rv64si` rows.
- The toolchain pin becomes a hard contract: `moonbit-version`, CI, and
  `moon.mod` dependency versions move together.
- After `v1.0` is tagged, new work starts from the post-`v1.0` backlog in
  `docs/roadmap.md` rather than by reopening closed tasks.
