# Task 0052: Browser Long-Run Refactor

## Background

Linux boot needs long execution windows, larger memory, and predictable serial draining. Those concerns should be made explicit before the browser host attempts to run the kernel to early boot logs.

## Work

- Refactor browser run scheduling so long runs do not block the page indefinitely
- Make memory sizing and guest image placement visible at the host boundary
- Keep serial output draining incremental and observable
- Keep reset behavior deterministic across bare-metal and Linux guest images

## Acceptance Criteria

- Long browser runs have an explicit scheduling policy
- Browser status and serial output remain responsive enough for manual boot inspection
- The refactor does not change core instruction semantics

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0051](0051-browser-linux-artifact-loader.md)

## Status

- `done`

## Progress Notes

- This is the second refactor task in the implementation/refactor alternating sequence
- Task 0051 provides the artifact-loading route; this refactor should make long browser execution, serial draining, and memory/performance assumptions explicit before attempting Linux boot
- The Wasm runtime now exposes `browser_run_for(step_budget)`, cumulative step count, artifact byte sizes, and guest kind
- Browser JS now has an explicit scheduling policy: smoke guest uses `4096` steps/tick and the Linux artifact guest uses `65536` steps/tick on a `16ms` interval
- The UI shows scheduler policy, executed steps, and artifact byte sizes so long-run behavior is visible before actual Linux boot
- Verified with `moon test`, `./scripts/build-browser-demo.sh`, the Wasm browser smoke, and the synthetic browser artifact-loader smoke
