# Task 0064: Docs Retarget

## Background

The owner rejected the `v1.0.0` framing and asked for a new direction
([ADR 0011](../adr/0011-no-version-tags-and-new-direction.md)). The docs tree
carried 61 completed task docs in the reading path.

## Scope

- Record ADR 0011 and ADR 0012, add Milestone 13.
- Archive completed task docs to `docs/history/tasks/` and fix links.
- Rewrite `docs/current.md`, `docs/roadmap.md`, `README.md`, and `AGENTS.md`
  for the new direction.
- Add `tools/check_doc_links.py` so link rot is caught mechanically.

## Acceptance Criteria

- `python3 tools/check_doc_links.py` reports no broken links.
- `grep -rn "v1\.0" README.md docs/current.md docs/roadmap.md` is empty.
- `git diff --check` is clean.

## Status

- `done`
