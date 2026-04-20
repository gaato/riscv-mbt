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

## Non-Goals

- Rich IDE-like front-end
- Preview deployment infrastructure beyond the first public smoke demo

## Exit Criteria

- Browser-hosted emulator can boot the prepared demo image
- UI remains a thin host over the shared core
- Browser hosting does not become the only way to exercise the emulator
- A public smoke-demo URL exists for the browser host

## Required Tests

- Smoke test for browser entrypoint
- Manual verification checklist for serial interaction
- Deployment smoke check for the published build artifact

## Implementation Order

1. build the first minimal browser host artifact
2. deploy the first public smoke demo

## Current Checkpoint

- This milestone is complete
- The default hosting target is `GitHub Pages`
- The first minimal browser host artifact now exists under `_build/browser-demo/`
- The first public smoke demo is live at `https://gaato.github.io/riscv-mbt/`
- Preview deploys are intentionally out of scope for the current browser milestone contract

## Prerequisites For Next Milestone

- None
