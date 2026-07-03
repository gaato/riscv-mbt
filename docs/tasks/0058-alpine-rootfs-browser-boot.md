# Task 0058: Alpine Rootfs Browser Boot

## Background

The browser Wasm host can reach early Linux output with OpenSBI, a DTB, and a kernel image. The next goal is to boot a real lightweight userspace in a practical browser loop rather than stopping at early kernel serial markers.

Alpine is the first target because the official `riscv64` minirootfs is small, current, and easy to turn into an initramfs.

## Sources

- Linux RISC-V boot requirements: <https://docs.kernel.org/arch/riscv/boot.html>
- Linux RISC-V architecture index: <https://docs.kernel.org/arch/riscv/index.html>
- Alpine downloads page: <https://alpinelinux.org/downloads/>
- Alpine `riscv64` release directory: <https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/riscv64/>
- MoonBit bench/profile/tooling docs should be rechecked with official docs or Context7 before changing benchmark harnesses.
- `simmerv` remains a performance reference for uop/basic-block caching, TLB/cache split, and browser cycle-limited execution.

## Work

- Add an initrd artifact path to the browser Linux loader.
- Build an Alpine `riscv64` initramfs from the official minirootfs.
- Generate a DTB that includes `linux,initrd-start` and `linux,initrd-end` in `/chosen`.
- Keep OpenSBI handoff aligned with the Linux RISC-V boot ABI: `a0 = hart id`, `a1 = DTB`, `satp = 0`, RV64 kernel at a 2 MiB PMD boundary.
- Add a repeatable browser proof for reaching the Alpine init process or shell banner.
- Add `moon bench` and browser timing checkpoints before making backend or SIMD decisions.
- Decide between `wasm` and `wasm-gc` from measurements, not preference.

## Acceptance Criteria

- `_build/alpine-initramfs-riscv64.cpio.gz` and `_build/minimal-alpine.dtb` can be generated from official Alpine artifacts.
- The browser demo can load OpenSBI, DTB, kernel, and initrd artifacts from the manifest.
- Browser serial output reaches a clear Alpine initramfs marker.
- The selected backend is justified by measured browser boot time, steps/sec, cache counters, artifact size, and instantiate/compile cost.
- `moon check`, `moon test`, and `./scripts/build-browser-demo.sh` pass.
- Work is committed in meaningful increments; generated `outputs/` evidence remains ignored.

## Related Milestones

- Browser Wasm Linux Boot
- Verification, Debugging, And Performance
- Extensions: A, F/D, V, H

## Status

- `doing`

## Progress Notes

- Added `initrd` as a fourth browser artifact kind.
- Added `scripts/build-alpine-initramfs.sh` to fetch Alpine minirootfs, inject a tiny `/init`, build a compressed `newc` initramfs, and generate an initrd-aware DTB.
- Added DTB generator options for `linux,initrd-start` and `linux,initrd-end`.
- Generated Alpine 3.24.1 `riscv64` initramfs from the official minirootfs. The compressed initramfs is 3,442,976 bytes at `0x84000000..0x84348920`.
- Browser Chromium probe with 180s virtual time loaded OpenSBI, DTB, kernel, and initrd, reached Linux rootfs unpack (`Trying to unpack rootfs image as initramfs...`), but did not reach the injected `/init` marker yet.
- A 600s virtual-time probe was still running after roughly ten minutes of wall time and was interrupted; this confirms the next slice needs backend comparison and boot-path performance work before claiming practical Alpine userspace boot.
- `wasm-gc` built and ran the same Alpine probe successfully to the same initramfs-unpack point with a smaller artifact and substantially lower wall time than plain `wasm`; the browser demo now defaults to `wasm-gc` while keeping `BROWSER_TARGET=wasm` for comparison.
