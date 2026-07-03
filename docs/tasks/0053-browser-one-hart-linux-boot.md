# Task 0053: Browser One-Hart Linux Boot

## Background

After the Wasm host, runtime boundary, artifact loader, and long-run scheduler exist, the browser can attempt the same one-hart Linux boot path that is already validated outside the browser.

## Work

- Boot OpenSBI and the Linux kernel on one hart in the browser Wasm host
- Surface early serial output in the browser console
- Keep SMP and richer UI out of scope
- Record manual reproduction steps and observed boot output

## Acceptance Criteria

- Browser serial output reaches the OpenSBI banner
- Browser serial output reaches Linux early boot logs, ideally including `Linux version`
- Native one-hart Linux boot coverage remains green
- Browser Linux boot limitations are documented clearly

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0052](0052-browser-long-run-refactor.md)

## Status

- `done`

## Progress Notes

- This is the third implementation task in the implementation/refactor alternating sequence
- The Wasm host can now load the Linux artifact guest and has explicit long-run scheduling; this task should use real OpenSBI, DTB, and kernel artifacts and drive execution until early boot serial output is visible
- Verified the browser Wasm host with real OpenSBI, generated DTB, and the Debian riscv64 `vmlinux-6.12.73+deb13-riscv64` kernel artifact.
- Evidence: `outputs/webwright_browser_linux_boot/final_runs/run_1/final_script.py` reached `Linux version`, `earlycon`, and `Kernel command line` in browser serial output.
