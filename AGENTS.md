# Agent Guide

This repository is the source of truth for both implementation and AI-readable project context.

## Read This First

1. [README.md](README.md)
2. [docs/current.md](docs/current.md)
3. [docs/guides/implementation-notes.md](docs/guides/implementation-notes.md)
4. The active milestone doc in [docs/milestones](docs/milestones)
5. Any referenced task docs in [docs/tasks](docs/tasks)
6. Relevant ADRs in [docs/adr](docs/adr)

If the task is implementation work, prefer this reading order:

1. `docs/current.md`
2. the active task doc
3. the active milestone doc
4. `docs/guides/implementation-notes.md`
5. relevant ADRs

## Editable Areas

- MoonBit source lives in the repository root package and [cmd/main](cmd/main).
- Planning and execution state live under [docs](docs).
- Keep generated build output out of version control.

## Source Of Truth

- Repo Markdown is the canonical source of truth for roadmap, tasks, and current state.
- GitHub Issues and PRs may mirror or discuss work, but they should not become more specific than the repo docs.
- When docs and chat disagree, update the docs or explicitly record the new decision in an ADR.

## Spec Usage

- For RISC-V ISA or privileged behavior, do not rely only on memory or repo-local summaries when a precise rule matters.
- Re-check the official spec when implementing or changing:
  - instruction encodings or corner-case semantics
  - CSR behavior
  - trap/return flow
  - address translation
  - Linux boot assumptions
- Treat `docs/guides/implementation-notes.md` as guidance, not as a substitute for the normative spec text.

## TDD Rules

- Start each feature with a failing test.
- Prefer execute tests over broad snapshots for CPU behavior.
- Keep decode tests, execute tests, and small-program integration tests separate.
- Do not claim a milestone is complete until its doc and current task state are updated.
- When behavior is subtle, add the smallest possible regression that captures the spec rule.

## Emulator Design Rules

- Protect implementation boundaries before growing instruction coverage.
- Keep fetch, decode, CSR handling, trap flow, and address translation separable.
- Do not mix practical RV64-core stabilization with Linux platform bring-up in the same task unless the docs explicitly call for it.
- Treat Linux boot as a platform-integration milestone, not just an ISA milestone.
- Keep one-hart boot as the default baseline and add SMP only after single-hart behavior is stable.

## Task Update Rules

- `docs/current.md` must always describe the real current milestone and next task.
- Every meaningful implementation task should have a single Markdown file in `docs/tasks/`.
- Use only `todo`, `doing`, `blocked`, or `done` for task status.
- When a task changes state, update the task file and `docs/current.md` in the same change.
- If you finish a critical-path task, advance the current milestone or next-task text so the next agent is not forced to infer it.

## Design Decision Rules

- Record any non-trivial architecture or scope decision as an ADR in `docs/adr/`.
- If a change affects milestone shape, update the matching milestone doc and roadmap.
- If you discover a new “do this, not that” rule that future agents are likely to need, add it to `AGENTS.md` or `docs/guides/implementation-notes.md`.

## RV64 To Linux Path

On the general-purpose path, keep this order explicit:

1. RV64 sign-extension and `*W` correctness
2. practical RV64 core stabilization
3. `S`-mode and delegation
4. `Sv39` and `SFENCE.VMA`
5. OpenSBI and a `QEMU virt`-like platform
6. Linux boot ABI and one-hart boot
7. SMP only after the one-hart path is stable

Do not collapse these stages into one giant “Linux bring-up” task unless the repo docs have been rewritten to do so intentionally.

## Browser Deployment Rules

- The browser demo itself is a late milestone and follows Linux boot.
- Hosting can be decided earlier; the current default recommendation is `Cloudflare Pages` unless a concrete repo constraint changes that.
- Deployment is phased:
  - choose the host early
  - publish the first smoke demo once a browser artifact exists
  - enable preview deploys once browser work becomes an active review surface

## GitHub Issue Mirroring

- Repo Markdown is the canonical source of truth.
- GitHub Issues mirror milestone or task bundles for collaboration and visibility.
- When creating an issue, link back to the repo doc that owns the details.
