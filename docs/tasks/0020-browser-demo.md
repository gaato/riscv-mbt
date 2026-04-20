# Task 0020: Browser Demo

## Background

The browser host is a distinct product layer over the emulator core, not the place to hide core complexity.

## Work

- Compile or host the core through the browser-friendly MoonBit target
- Add a serial console and keyboard input
- Keep UI code thin and keep the core reusable outside the browser
- Integrate with the deployment tasks instead of inventing a separate browser-only release flow

## Acceptance Criteria

- The browser demo uses the shared core instead of a forked implementation
- Manual verification steps for console interaction exist
- Deployment assumptions are recorded in the linked hosting tasks

## Related Milestone

- `Browser Demo`

## Dependencies

- [Task 0019](0019-verification-debug-performance.md)
- [Task 0021](0021-browser-hosting-decision.md)

## Status

- `done`

## Progress Notes

- The repo now has a minimal browser host built on the shared core
- The host lives in `cmd/browser` and is packaged into `_build/browser-demo/` by `./scripts/build-browser-demo.sh`
- The current smoke scope is intentionally small:
  - serial console view
  - `step` / `run` / `reset` controls
  - UART input textbox that feeds the guest RX queue
  - status readout for `pc`, privilege mode, and a few integer registers
- Manual verification on 2026-04-20:
  - run `./scripts/build-browser-demo.sh`
  - open `_build/browser-demo/index.html` in a browser
  - verify the serial console starts with `echo ready` and a prompt
  - type text into the UART input field and press Enter
  - verify the guest echoes the submitted text through the serial console
  - click `Step` and `Run` to confirm the controls update the host status without forking emulator logic
