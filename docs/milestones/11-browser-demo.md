# Milestone 11: Browser Demo

## Purpose

Expose the emulator through a browser UI without entangling the core with presentation code.

## Target Instructions / Features

- JS/Wasm target
- Serial console view
- Keyboard input
- Minimal boot controls
- Reuse of the same core that passed the non-browser verification milestones
- A documented hosting target for browser deployments
- A path from one public smoke-demo deployment to repeatable preview deployments

## Non-Goals

- Rich IDE-like front-end

## Exit Criteria

- Browser-hosted emulator can boot the prepared demo image
- UI remains a thin host over the shared core
- Browser hosting does not become the only way to exercise the emulator
- Browser deployment is routine enough that demo changes can be reviewed from a URL

## Required Tests

- Smoke test for browser entrypoint
- Manual verification checklist for serial interaction
- Deployment smoke check for the published build artifact

## Implementation Order

1. build the first minimal browser host artifact
2. deploy the first public smoke demo
3. enable preview deploys for browser-facing work

## Current Checkpoint

- This is now the active mainline milestone
- The default hosting target is `GitHub Pages`
- The first minimal browser host artifact now exists under `_build/browser-demo/`
- The next active task is [Task 0022](../tasks/0022-browser-smoke-demo-deploy.md), which now has a GitHub Pages workflow but still needs the first public URL confirmation

## Prerequisites For Next Milestone

- None
