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

- `doing`

## Progress Notes

- This is now the active browser implementation task
- The goal is to produce the first minimal browser host artifact that `0022` can deploy, not to fold deployment work into the host task
