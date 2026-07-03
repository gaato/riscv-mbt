# Task 0051: Browser Linux Artifact Loader

## Background

The native Linux boot path already loads OpenSBI, a DTB, and a Linux kernel. The browser path needs an equivalent artifact-loading route that does not bake Linux assumptions into the emulator core.

## Work

- Add a browser-compatible route for OpenSBI, DTB, and Linux kernel bytes
- Reuse the existing boot ABI and platform setup where possible
- Keep one-hart boot as the only browser Linux target for this slice
- Document artifact size and hosting assumptions

## Acceptance Criteria

- The browser host can obtain guest artifacts and place them at the expected addresses
- The host can choose between the existing bare-metal smoke image and the Linux boot image
- Native Linux boot tests remain the source of truth for core boot semantics

## Browser Artifact Contract

- Browser artifacts are served from `_build/browser-demo/linux-artifacts/`
- `linux-artifacts/manifest.json` names:
  - `opensbi-riscv64-fw_dynamic.bin`
  - `minimal.dtb`
  - `linux-kernel-riscv64`
- `./scripts/build-browser-demo.sh` always copies the manifest and copies those binaries from `_build/` when they exist locally
- The browser UI can choose the smoke guest or load the Linux artifact guest; actual Linux execution remains a later task
- Real kernel artifacts may be large, so long-run scheduling and performance tuning stay in Task 0052

## Related Milestone

- `Browser Wasm Linux Boot`

## Dependencies

- [Task 0050](0050-browser-runtime-boundary-refactor.md)

## Status

- `done`

## Progress Notes

- This is the second implementation task in the implementation/refactor alternating sequence
- Start from the runtime boundary established in Task 0050; do not add Linux-specific state directly to UI handlers
- Added a browser Linux artifact manifest and optional build-script copying for OpenSBI, DTB, and kernel files from `_build/`
- Added Wasm runtime APIs to stream artifact chunks into the emulator, place OpenSBI at `0x80000000`, place the kernel at `0x80200000`, load the DTB at `config.dtb_addr`, and build the `fw_dynamic_info` handoff
- Added UI controls for choosing the smoke guest or loading the Linux artifact guest
- Verified the browser loader with synthetic manifest artifacts in `outputs/webwright_linux_artifact_loader/final_runs/run_1/`; the browser reports all artifacts loaded and `pc=0x80000000`
