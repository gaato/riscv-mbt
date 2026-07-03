# Task 0058: Alpine Rootfs Browser Boot

## Background

The browser Wasm host can reach early Linux output with OpenSBI, a DTB, and a kernel image. The next goal is to boot a real lightweight userspace in a practical browser loop rather than stopping at early kernel serial markers.

Alpine is the first target because the official `riscv64` minirootfs is small, current, and easy to turn into an initramfs.

## Sources

- Linux RISC-V boot requirements: <https://docs.kernel.org/arch/riscv/boot.html>
- Linux RISC-V architecture index: <https://docs.kernel.org/arch/riscv/index.html>
- Linux initramfs buffer format: <https://docs.kernel.org/driver-api/early-userspace/buffer-format.html>
- Alpine downloads page: <https://alpinelinux.org/downloads/>
- Alpine `riscv64` release directory: <https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/riscv64/>
- MoonBit bench/profile/tooling docs should be rechecked with official docs or Context7 before changing benchmark harnesses.
- `simmerv` remains a performance reference for uop/basic-block caching, TLB/cache split, and browser cycle-limited execution.

## Work

- Add an initrd artifact path to the browser Linux loader.
- Build an Alpine `riscv64` initramfs from the official minirootfs. The browser-practical default is a `tiny` profile containing Alpine's BusyBox and musl loader/libc; `ALPINE_INITRD_PROFILE=full` still builds the whole minirootfs.
- Generate a DTB that includes `linux,initrd-start` and `linux,initrd-end` in `/chosen`.
- Keep OpenSBI handoff aligned with the Linux RISC-V boot ABI: `a0 = hart id`, `a1 = DTB`, `satp = 0`, RV64 kernel at a 2 MiB PMD boundary.
- Add a repeatable browser proof for reaching the Alpine init process or shell banner.
- Add `moon bench` and browser timing checkpoints before making backend or SIMD decisions.
- Decide between `wasm` and `wasm-gc` from measurements, not preference.

## Acceptance Criteria

- `_build/linux-kernel-riscv64`, `_build/alpine-initramfs-riscv64.cpio`, `_build/alpine-initramfs-riscv64.cpio.gz`, and `_build/minimal-alpine.dtb` can be generated from official Alpine artifacts.
- The browser demo can load OpenSBI, DTB, kernel, and initrd artifacts from the manifest.
- Browser serial output reaches a clear Alpine initramfs marker. This is satisfied by the default static `/init` writing `riscv-mbt Alpine initramfs ready` through `/dev/kmsg`; browser Wasm also reaches a second `riscv-mbt Alpine shell alive` marker emitted by BusyBox shell itself, the BusyBox `/ #` prompt, and a returned `browser-input-ok` from a browser-injected `echo browser-input-ok` command.
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
- Alpine's official Generic U-Boot tarball includes `boot/vmlinuz-lts`, which is a gzip-compressed RISC-V boot executable `Image`. Passing the compressed file directly does not progress past OpenSBI, but gzip-expanding it produces a valid direct-boot kernel image.
- `scripts/build-alpine-initramfs.sh` now downloads and verifies Alpine's Generic U-Boot tarball and writes the expanded `boot/vmlinuz-lts` to `_build/linux-kernel-riscv64`.
- Native Alpine probe with the expanded Alpine Image reaches Linux and initramfs unpacking. `medium` (100M steps) reaches kernel init around futex setup in about 8s wall time; `xlong` (1B steps) reaches `Unpacking initramfs...` and `workingset` after about 105s wall time, but does not reach the injected `/init` marker yet.
- Browser `wasm-gc` probe with 180s Chromium virtual time and the expanded Alpine Image reaches `Unpacking initramfs...`, but does not reach the injected `/init` marker yet.
- With `_build/linux-kernel-riscv64` generated from Alpine's expanded Image, the existing Task 0015 Linux boot regression reaches `Linux version` in about 7M steps instead of the prior Debian-kernel path's 19M-step observation.
- Added a native Alpine probe marker check for Alpine's `Unpacking initramfs...` log form as well as the older Debian-style initramfs message.
- Added a first `moon bench` CPU loop checkpoint. On this host, `tight_add_loop_100k_steps` measured about 4.93ms mean across 10 x 21 runs.
- Tried increasing the direct-mapped decode cache from 4096 to 65536 sets. It reduced the native Alpine `medium` decode misses from about 15.8M to 0.9M, but did not improve wall time (about 56.6s baseline versus about 57.9s with the larger cache), so the cache size remains 4096 and the next performance work should look past simple decode-cache capacity.
- Switched the default Alpine initramfs artifact to uncompressed `newc` cpio while still generating `.cpio.gz` for comparison. Linux's initramfs buffer format explicitly allows compressed and uncompressed `newc` archives.
- With the uncompressed cpio initramfs, native Alpine `long` (300M steps) reaches `Unpacking initramfs...` and `workingset` in about 167s wall time. This is still not the injected `/init` marker, but it reaches the initramfs phase much earlier than the prior gzip-based 1B-step observation.
- Browser `wasm-gc` probe against `/?guest=linux&autoRun=1` with 180s Chromium virtual time loaded the 7,205,888 byte uncompressed initramfs and reached `Unpacking initramfs...`.
- Added root-owned `/dev/console`, `/dev/null`, `/dev/zero`, and `/dev/tty` device nodes to generated initramfs archives through `fakeroot`, matching Linux early-userspace expectations without requiring host root.
- Added a `tiny` Alpine initramfs profile sourced from the official minirootfs (`/bin/busybox`, `/bin/sh`, musl loader/libc, `/init`, and minimal pseudo-filesystem directories). This reduces the uncompressed initramfs from about 7.2MB to about 1.4MB and reaches `Freeing initrd memory` in native `long`.
- Added `ALPINE_TIMEBASE_FREQUENCY`; the practical default is now 100MHz. With the `tiny` profile and 100MHz DTB, native `long` reaches ttyS0 enablement, and native `xxlong` reaches `Run /init as init process`.
- Cross-checked the same tiny Alpine initramfs under `qemu-system-riscv64`; QEMU reaches the injected `riscv-mbt Alpine initramfs ready` marker, proving the artifact is valid.
- The native `xxlong` path now reaches `/init`, but the injected marker is still not observed in riscv-mbt. The previous panic was an Alpine hard-float userland issue: musl executed compressed `FSD` (`0xb920`) while the virt machine exposed only `rv64imac`. The emulator now decodes compressed `C.FLD`/`C.FSD` forms, and the virt platform exposes `F/D`; the remaining gap is after `Run /init as init process`.
- Browser `wasm-gc` probe with the default tiny/100MHz artifacts and 360s Chromium virtual time reaches `Run /init as init process`. The injected Alpine marker is still not observed; the next slice should make the `/init` shell output visible or identify the userland wait after exec.
- Latest `moon bench` checkpoint: `tight_add_loop_100k_steps` measured about 5.07ms mean across 10 x 20 runs.
- Added `ALPINE_INIT_STYLE=static|shell`. The default `static` style assembles `tools/alpine-init.S` into a freestanding RV64 `/init`; the old shell script remains available with `ALPINE_INIT_STYLE=shell`.
- Added `/dev/kmsg` to the generated initramfs and changed the static `/init` marker path to write through kmsg. Direct writes to inherited stdio and `/dev/console` reached the static init loop under riscv-mbt native but did not appear in the captured serial log; kmsg goes through the existing kernel log path and is visible in QEMU, native, and browser probes.
- QEMU cross-check with the static kmsg init reaches `Run /init as init process`, `riscv-mbt Alpine initramfs ready`, and `riscv-mbt Alpine init exec failed` without kernel panic.
- Native `moon run cmd/alpine_probe --target native -- xxlong` now reaches `outcome=alpine-marker` at 355,000,000 steps with the default tiny/static artifacts.
- Browser `wasm-gc` probe against `/?guest=linux&autoRun=1` with 360s Chromium virtual time reaches `riscv-mbt Alpine initramfs ready` with the 1,442,304 byte uncompressed initramfs.
- The initial static `/init` handoff to `/bin/sh` failed with `EFAULT` because linker relaxation generated `gp`-relative data accesses for `argv`/`envp`, while the freestanding entry point had not initialized `gp`.
- `tools/alpine-init.S` now initializes `gp` from `__global_pointer$` before accessing static data. QEMU reaches `riscv-mbt Alpine initramfs ready` and then `/bin/sh: can't access tty; job control turned off` followed by a BusyBox `/ #` prompt.
- Browser `wasm-gc` with the same artifact still reaches the kmsg marker, but a 360s Chromium virtual-time probe for `/ #` did not observe the prompt. The next Task 0058 slice should focus on why BusyBox/TTY output is not visible through riscv-mbt/browser even though QEMU shows it.
- Changed the static init handoff to run `/bin/sh -c 'echo riscv-mbt Alpine shell alive > /dev/kmsg; exec /bin/sh'`. QEMU shows both the shell-alive marker and the BusyBox `/ #` prompt.
- Browser `wasm-gc` with 480s Chromium virtual time reaches `riscv-mbt Alpine shell alive` with the 1,443,328 byte uncompressed initramfs. This proves the Alpine BusyBox shell executes in browser Wasm; the remaining gap is interactive TTY output/input visibility rather than ELF/userland execution.
- Added minimal 16550A state for `IER`, `IIR`, `LCR/DLAB`, UART receive-data and transmit-empty interrupt identification, and PLIC source 10 claimability. This lets Linux's normal serial TTY path make progress instead of relying only on polling console/kmsg output.
- Native `moon run cmd/alpine_probe --target native -- xxlong` now reaches `outcome=alpine-shell-prompt` at 357,000,000 steps with `/bin/sh: can't access tty; job control turned off` and `/ #` in the captured UART tail.
- Browser `wasm-gc` with 480s Chromium virtual time now reaches the BusyBox `/ #` prompt.
- Added browser query automation for post-marker UART input: `linuxInputAfterMarker` and `linuxInput`. A 720s Chromium virtual-time probe using `linuxInputAfterMarker=/ #` and `linuxInput=echo browser-input-ok` observes the command echo and `browser-input-ok` output, proving browser-to-Alpine-shell input/output round trip.
- Increased the browser Linux run quantum from 65,536 to 262,144 steps/tick and throttled DOM/status synchronization to every 16 scheduler ticks while the guest is running. Manual controls still force immediate synchronization.
- With the larger run quantum and throttled UI sync, the same browser interactive probe succeeds with a 30s Chromium virtual-time budget. On this host, `/usr/bin/time` measured about `wall=1:15.90` for the `browser-input-ok` round trip.
- `tools/browser_linux_probe.py` now has a first-class interactive Alpine smoke mode. After `./scripts/build-browser-demo.sh`, run `python3 tools/browser_linux_probe.py --serve-dir _build/browser-demo --alpine-interactive-smoke --budget-ms 30000 --wall-timeout 180` to start a temporary local HTTP server, boot the browser Linux guest, inject `echo browser-input-ok` after the BusyBox `/ #` prompt, and require the shell response.
- Re-ran `moon bench` after the interactive smoke cleanup: `tight_add_loop_100k_steps` measured `4.97 ms +/- 85.25 us` across `10 x 20` runs. A fresh DeepWiki pass over `tommythorn/simmerv` again points to basic-block/uop caching, split TLBs, event-queued device work, and cooperative browser cycle scheduling as the relevant performance ideas; this repo already has decode and translation caches, so the next risky-but-promising slice is a bounded basic-block/uop fast path rather than another simple cache-size tweak.
- Added browser scheduler query overrides for `linuxStepsPerTick` and `syncEveryTicks`, exposed by `tools/browser_linux_probe.py` as `--linux-steps-per-tick` and `--sync-every-ticks`. Re-measured the interactive smoke on this host: default 262,144 steps/tick with 16-tick sync was `wall=1:18.29`; 524,288 steps/tick with 16-tick sync worsened to `wall=2:30.80`; 1,048,576 steps/tick timed out at 180s; keeping 262,144 steps/tick and using 32-tick sync reached `wall=1:15.88`; 64-tick sync reached `wall=1:16.30`. The default is now 262,144 steps/tick with 32-tick sync, and the default smoke re-run reached `wall=1:15.69`. `moon bench` after this browser-only change measured `tight_add_loop_100k_steps` at `5.04 ms +/- 81.45 us` across `10 x 20` runs.
- Tried an explicit browser-only `mtime` increment experiment because RISC-V `mtime` is a platform real-time counter rather than a per-instruction counter. It did not improve wall time: `mtimeIncrement=4` reached the shell at `wall=1:16.29`, while `mtimeIncrement=16` failed to reach the prompt within the 30s Chromium virtual-time budget. The API and query hook were not kept.
- Tried a narrow `ADDI`/`JAL` inline fast path inside `Runner::step` as a lower-risk precursor to a uop/basic-block executor. It was not kept: `moon bench` stayed in the same noise band (`4.97..5.06 ms` for `tight_add_loop_100k_steps`) and the browser Alpine smoke still reached `browser-input-ok` but measured `wall=1:18.62`. The next useful core-side performance slice needs to skip repeated fetch/decode/translation across a bounded block rather than only reducing one dispatch layer.
- Prototyped a private bounded block cache for a small arithmetic/branch subset. It improved the synthetic tight loop substantially (`tight_add_loop_100k_steps` reached `2.10 ms +/- 12.81 us`) but was not safe enough for Linux boot: applying it in M-mode stalled before serial output, excluding M-mode still stalled before Linux output, and limiting it to Sv39-active S-mode still stalled after OpenSBI with no `/ #` prompt. The implementation was removed; the next attempt needs stronger invalidation/provenance rules before executing cached blocks on the Linux path.
- Added [ADR 0009](../adr/0009-bounded-uop-cache-safety.md) to pin the next bounded uop/basic-block cache attempt behind explicit provenance, invalidation, per-instruction timer/interrupt preservation, and Linux/browser verification gates. The practical next implementation should start with an over-flushing, register-only block subset rather than another broad Linux-path shortcut.
- Validation after the ADR/docs update: `moon check`, `moon test`, `moon bench`, and `./scripts/build-browser-demo.sh` passed. `moon bench` measured `tight_add_loop_100k_steps` at `5.05 ms +/- 107.03 us` across `10 x 21` runs. The browser Alpine interactive smoke reached `browser-input-ok` at `wall=1:16.28`, matching the current 75-76s wall-time band.
- Tried an ADR 0009-style narrow `ADDI; JAL -4` block cache with a RAM generation key and conservative flushes. It improved the synthetic loop (`tight_add_loop_100k_steps` reached `1.78..2.29 ms` across iterations), but was not kept because the browser Alpine interactive smoke timed out at 180s even after Linux-platform bypassing was added. After reverting the implementation, baseline validation passed again: `moon check`, `moon bench` (`tight_add_loop_100k_steps` at `4.94 ms +/- 46.91 us`), `./scripts/build-browser-demo.sh`, and browser Alpine interactive smoke at `wall=1:16.45`. The lesson is that a `run()`-fronted block-cache probe still adds too much browser Linux overhead; the next attempt should either integrate with the existing fetch/decode path after a proven hot backward branch or collect browser-side hot-PC evidence before adding any per-step lookup.
- Added an optional browser hot-PC sampler controlled by `hotPcSamples` / `tools/browser_linux_probe.py --hot-pc-samples`. It samples only at browser tick boundaries after `browser_run_for`, so the default path has no sampling overhead and the sampler avoids MoonBit per-step instrumentation. With `--hot-pc-samples 4096`, browser Alpine interactive smoke still reached `browser-input-ok` at `wall=1:17.06` and collected 1856 samples before the 30s Chromium virtual-time budget ended. The top PCs were `0xffffffff80899ce6:13`, `0xffffffff80899cdc:9`, `0xffffffff80899cde:6`, `0xffffffff80899ce4:6`, `0xffffffff8034186e:5`, `0xffffffff8033b7a8:5`, `0xffffffff8033b6ea:5`, and `0xffffffff80899ce0:4`. A normal sampler-disabled browser Alpine smoke then reached `browser-input-ok` at `wall=1:16.11`. `moon bench` measured `tight_add_loop_100k_steps` at `5.41 ms +/- 294.40 us` in the usual noise band.
- Added `tools/resolve_hot_pcs.py` so sampled kernel PCs can be resolved against `_build/System.map-*-lts` and, when `_build/linux-kernel-riscv64` is present, disassembled from the raw kernel `Image`. Resolving the first browser hot-PC sample mapped five of the top eight PCs into `memcpy`, specifically the aligned word-copy loop around `lw`, `sw`, and `bltu`; the remaining top entries mapped to `jent_memaccess` and `keccakf_round`. This makes the next performance target more concrete: the Linux/browser path is currently showing kernel copy and entropy/crypto work rather than the tiny backward `ADDI; JAL` loop shape that the reverted block-cache experiments optimized. The next optimization attempt should either target load/store-heavy kernel copy behavior or collect a broader sample before re-entering uop cache work.
- Added `word_copy_loop_100k_steps`, a small RV64 bench shaped like the hot kernel `memcpy` loop (`lw; addi; sw; addi; bltu`). The first baseline measured `12.81 ms +/- 403.29 us`. Refactoring integer `execute_load` and `execute_store` to avoid the higher-order `load_and_write` / `store_and_commit` closures on the common integer path reduced that bench to `11.77 ms +/- 225.98 us`, while `tight_add_loop_100k_steps` stayed in the usual noise band at `4.87 ms +/- 55.16 us`. Validation passed with `moon check`, `moon test`, `moon bench`, `./scripts/build-browser-demo.sh`, and the browser Alpine interactive smoke reached `browser-input-ok` at `wall=1:17.11`, so this is a small measured load/store-path improvement rather than a practical browser wall-time breakthrough.
- Tried reusing the physical RAM/MMIO dispatch result for the hot 32-bit `Lw`/`Lwu`/`Sw` path to avoid a second `phy_dispatch` after `load_check` / `store_check`. It was not kept: `moon bench` measured `word_copy_loop_100k_steps` at `11.95 ms +/- 211.89 us`, worse than the simpler integer-dispatch refactor. The next load/store attempt should avoid broadening the execution path unless it removes more work than this target-carrying variant did.
- Added `dword_copy_loop_100k_steps`, a matching RV64 `ld; addi; sd; addi; bltu` bench for 64-bit RAM paths. The initial no-Bus-change baseline measured `word_copy_loop_100k_steps` at `11.47 ms +/- 443.78 us` and `dword_copy_loop_100k_steps` at `7.42 ms +/- 74.13 us`. Hand-expanding Bus raw word/dword memory indexing did not help and was not kept: changing `load_raw_u16`/`load_raw_u32` plus `store_u16`/`store_u32`/`store_u64` measured `word_copy_loop_100k_steps` at `11.57 ms +/- 232.02 us` and `dword_copy_loop_100k_steps` at `7.59 ms +/- 80.12 us`; changing only `load_u64` measured `dword_copy_loop_100k_steps` at `7.62 ms +/- 115.42 us`. The next useful path is not manual byte-index expansion in `Bus`.
