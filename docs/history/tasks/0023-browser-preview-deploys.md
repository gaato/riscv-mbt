# Task 0023: Enable Preview Deploys For Browser Work

## Background

Preview deployments are most valuable once the browser demo becomes an active development surface. They are less urgent before there is a stable smoke-demo deployment path.

## Work

- Re-evaluate whether branch or pull-request preview deployments are necessary after the first public smoke demo is live
- Keep `main` as the production browser demo path
- If preview review remains unnecessary, close the task without adding more hosting machinery

## Acceptance Criteria

- The repo docs explicitly state whether preview review is part of the browser milestone contract
- The browser delivery path no longer depends on inferred preview-hosting requirements

## Related Milestone

- `Browser Demo`

## Dependencies

- [Task 0021](0021-browser-hosting-decision.md)
- [Task 0022](0022-browser-smoke-demo-deploy.md)

## Status

- `done`

## Progress Notes

- The browser milestone now stops at the public GitHub Pages smoke demo
- Additional preview deploys are intentionally out of scope for the current repo contract
- Local development plus the public smoke URL at `https://gaato.github.io/riscv-mbt/` are sufficient for the current browser delivery checkpoint
