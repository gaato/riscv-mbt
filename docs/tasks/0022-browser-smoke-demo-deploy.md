# Task 0022: Deploy The First Browser Smoke Demo

## Background

The first deployment should happen as soon as there is a small browser artifact worth sharing, rather than waiting for full Linux-in-browser support.

## Work

- Publish the first minimal browser demo
- Keep the scope to a smoke-demo level, such as stepping, register display, or a tiny bare-metal program
- Document the build output path and deployment expectations

## Acceptance Criteria

- A public URL exists for the first browser smoke demo
- The demo is small enough to validate the deployment path without entangling full browser product work

## Related Milestone

- `Browser Demo`

## Dependencies

- [Task 0020](0020-browser-demo.md)
- [Task 0021](0021-browser-hosting-decision.md)

## Status

- `done`

## Progress Notes

- The repo now includes a GitHub Pages workflow at `.github/workflows/browser-demo-pages.yml`
- The deployment build uses `./scripts/build-browser-demo.sh` and uploads `_build/browser-demo/` as the Pages artifact
- The first public smoke deploy is live at `https://gaato.github.io/riscv-mbt/`
- Manual smoke checks confirmed that the page loads, the console starts with `echo ready`, and UART input is echoed back through the shared core
