# Current State

## Current Milestone

- `Extensions: A, F/D, V, H`

## Current Tasks

- [Bootstrap the repo operating system](tasks/0001-bootstrap-operating-system.md) — `done`
- [Implement the RV32I bootstrap subset](tasks/0002-rv32i-bootstrap-subset.md) — `done`
- [Finish remaining RV32I base instruction coverage](tasks/0003-rv32i-complete-base-core.md) — `done`
- [Introduce riscv-tests for RV32I regression](tasks/0004-riscv-tests-integration.md) — `done`
- [Implement RV32IM](tasks/0005-rv32im.md) — `done`
- [Implement RV32IMC](tasks/0006-rv32imc.md) — `done`
- [Add Zicsr and Zifencei](tasks/0007-rv32imc-zicsr-zifencei.md) — `done`
- [Add minimal M-mode](tasks/0008-minimal-m-mode.md) — `done`
- [Machine reset and trap-entry invariants](tasks/0028-machine-reset-and-trap-entry.md) — `done`
- [Machine return and `mstatus` semantics](tasks/0029-machine-return-and-mstatus.md) — `done`
- [Add `mip` skeleton and machine CSR contract](tasks/0030-mip-skeleton-and-machine-csr-contract.md) — `done`
- [Optional RV32 supervisor + Sv32 path](tasks/0009-rv32-supervisor-sv32.md) — `todo`
- [Establish RV64 sign-extension invariants](tasks/0010-rv64-transition.md) — `done`
- [XLEN plumbing and RV64 state](tasks/0031-xlen-plumbing-and-rv64-state.md) — `done`
- [RV64I sign extension and word ops](tasks/0032-rv64i-sign-extension-and-word-ops.md) — `done`
- [RV64M word ops and transition closure](tasks/0033-rv64m-word-ops-and-transition-closure.md) — `done`
- [Stabilize the practical RV64 core](tasks/0011-rv64-practical-core.md) — `done`
- [RV64 carry-forward of `C`, `Zicsr`, and `Zifencei`](tasks/0034-rv64-carry-forward-of-c-zicsr-zifencei.md) — `done`
- [ELF64 loader and RV64 official plumbing](tasks/0035-elf64-loader-and-rv64-official-plumbing.md) — `done`
- [RV64 official survey and practical-core closure](tasks/0036-rv64-official-survey-and-practical-core-closure.md) — `done`
- [Add S-mode and delegation](tasks/0012-s-mode-and-delegation.md) — `done`
- [Supervisor CSR surface and trap entry](tasks/0037-supervisor-csr-surface-and-trap-entry.md) — `done`
- [Delegation routing and `SRET`](tasks/0038-delegation-routing-and-sret.md) — `done`
- [S-mode closure before `Sv39`](tasks/0039-s-mode-closure-before-sv39.md) — `done`
- [Add Sv39 and SFENCE.VMA](tasks/0013-sv39-and-sfence-vma.md) — `done`
- [Integrate OpenSBI and a virt-like platform](tasks/0014-opensbi-and-virt-platform.md) — `done`
- [Meet the Linux boot ABI on one hart](tasks/0015-linux-boot-abi-single-hart.md) — `done`
- [Add SMP after single-hart boot](tasks/0016-smp-after-single-hart.md) — `done`
- [Load official `riscv-tests` binaries](tasks/0024-official-riscv-tests-loader.md) — `done`
- [Add minimal `env/p` support](tasks/0025-minimal-env-p-support.md) — `done`
- [Run an official `rv32ui-p-*` subset](tasks/0026-official-rv32ui-runner.md) — `done`
- [Cross-check official `rv32ui-p-*` with a system emulator](tasks/0027-qemu-cross-check-official-rv32ui.md) — `done`
- [Browser demo host](tasks/0020-browser-demo.md) — `done`
- [Decide the browser demo hosting target](tasks/0021-browser-hosting-decision.md) — `done`
- [Deploy the first browser smoke demo](tasks/0022-browser-smoke-demo-deploy.md) — `done`
- [Enable preview deploys for browser work](tasks/0023-browser-preview-deploys.md) — `done`
- [Define the post-Linux compatibility target](tasks/0017-post-linux-compatibility.md) — `done`
- [Add post-Linux extensions in priority order](tasks/0018-extensions-a-fd-v-h.md) — `doing`
- [Bring up scalar `F`](tasks/0040-f-scalar-bring-up.md) — `done`
- [Bring up `D`](tasks/0041-d-extension-bring-up.md) — `done`
- [Close the post-`F/D` phase](tasks/0042-post-fd-closure.md) — `done`
- [Evaluate the first `V` slice](tasks/0043-vector-extension-evaluation.md) — `done`
- [Bring up `vsetvl*` and the first vector execute slice](tasks/0044-vsetvl-and-first-vector-execute-slice.md) — `done`
- [Implement the first vector arithmetic slice](tasks/0045-first-vector-arithmetic-slice.md) — `done`
- [Implement the first vector memory slice](tasks/0046-first-vector-memory-slice.md) — `done`
- [Implement the first masked and broader vector execute slice](tasks/0047-masked-and-broader-vector-execute-slice.md) — `done`
- [Implement the next broader vector memory and `LMUL` slice](tasks/0048-broader-vector-memory-and-lmul-slice.md) — `doing`
- [Move the browser smoke host to Wasm](tasks/0049-browser-wasm-smoke-host.md) — `done`
- [Refactor the browser runtime boundary](tasks/0050-browser-runtime-boundary-refactor.md) — `done`
- [Add a browser Linux artifact loader](tasks/0051-browser-linux-artifact-loader.md) — `done`
- [Refactor browser long-run behavior](tasks/0052-browser-long-run-refactor.md) — `done`
- [Boot Linux on one hart in browser Wasm](tasks/0053-browser-one-hart-linux-boot.md) — `done`
- [Refactor browser Linux observability](tasks/0054-browser-linux-observability-refactor.md) — `done`
- [Move the browser host to the plain Wasm backend](tasks/0055-browser-plain-wasm-backend.md) — `done`
- [Add simmerv-inspired cache performance improvements](tasks/0056-simmerv-inspired-cache-performance.md) — `done`
- [Refactor MoonBit execution surfaces before the next vector slice](tasks/0057-moonbit-refactoring-pre-0048.md) — `done`
- [Boot an Alpine rootfs in browser Wasm](tasks/0058-alpine-rootfs-browser-boot.md) — `doing`

## Next Task

- Next: continue the spec/extension mainline after the first `LMUL=2` unit-stride, strided `e32`, indexed `e32`, mask load/store vector memory slices, first `LMUL=2` add/move arithmetic slice, first vector subtract slice, first vector bitwise logical slice, and first vector min/max slice ([Task 0048](tasks/0048-broader-vector-memory-and-lmul-slice.md)). Keep the Alpine path ([Task 0058](tasks/0058-alpine-rootfs-browser-boot.md)) as an integration and regression gate for Linux usability, not as the main work queue for one-second wall-time shaving. The working priority is now: first RISC-V/Linux spec compliance and ISA extension coverage using the upstream Linux RISC-V architecture documentation index plus the RISC-V ISA specs, second functional Linux proofs through console/native probes, third refactoring that keeps those surfaces maintainable, and only then measured tuning when it supports or protects the first two priorities. Browser tests are no longer required for every implementation slice; the current practical artifact path still uses the Alpine `tiny` initramfs profile, a static kmsg-marker `/init`, uncompressed `newc` cpio, a 100MHz DTB timebase, `wasm-gc`, and a virt platform that exposes `F/D` for Alpine hard-float userland.

## Known Blockers

- Local `moon test` now expects build artifacts under `_build/riscv-tests-src/isa`; run `./scripts/build-riscv-tests-official.sh` first if they are missing.
- The built upstream `*-p-*` survey currently stands above the original RV32 checkpoint, but RV64 coverage is still survey-only and has not been promoted into the always-green CI subset.
- The official QEMU cross-check path remains RV32-only; RV64 system-emulator cross-checking is still deferred.
- The post-Linux compatibility target is fixed and the required `F/D` gap is closed. The first `V` state/CSR slice, `vsetvl*` execute path, first narrow arithmetic slice, first narrow unit-stride memory slice, first masked arithmetic slice, first `LMUL=2` unit-stride memory path, first strided `e32` memory path, first indexed `e32` memory paths, vector mask load/store, first `LMUL=2` add/move arithmetic path, first vector subtract path, first vector bitwise logical path, and first vector min/max path are now in place. Wider vector execution semantics beyond the first `LMUL=2` slices, broader vector memory forms, restart semantics, and richer Linux-oriented ISA coverage remain open.
- The browser host now builds as a Wasm artifact and the bare-metal browser smoke path is green. The Alpine rootfs path currently defaults to `wasm-gc`, while plain `wasm` remains available via `BROWSER_TARGET=wasm`. The browser runtime boundary is split between guest image construction, browser runtime state, Wasm exports, and JS UI glue. The browser can load OpenSBI, DTB, kernel, and initrd artifact bytes through a manifest, switch to the Linux artifact guest, expose explicit long-run scheduling, report boot marker progress, and reach initramfs unpacking in browser Wasm.
- JS string interop is no longer required for the active browser artifact; UART input and Linux artifacts use byte-oriented exports.
- The first `simmerv`-inspired performance slice is in place: decode cache, Sv39 translation cache, cache counters in tests/browser UI, and Linux boot timing observations. Basic-block/uop caching and a larger common-instruction fast executor are intentionally left as follow-up work.
- The Linux boot ABI contract is pinned to the upstream Linux RISC-V boot requirements: kernel entry uses `a0` for hart id, `a1` for DTB address, `satp = 0`, and RV64 kernel Image placement at a 2 MiB PMD boundary.
- Future Linux-specific compatibility checks should start from the upstream Linux RISC-V architecture documentation index, especially boot image header, VM layout, hwprobe, and vector support.
- A MoonBit refactor slice split FP execution into `riscv_fp.mbt` and vector execution into `riscv_vector.mbt`; `riscv_execute.mbt` is now below the 2k-line guideline and remains the central dispatcher.
- Browser Wasm Linux boot is complete, and the mainline has resumed at `0048`. Alpine rootfs browser boot remains active as an integration gate for real Linux behavior.
- The active goal is ordinary Linux usability with RISC-V/Linux spec compliance as the higher priority. Work should primarily advance behavior covered by the upstream Linux RISC-V architecture documentation index, RISC-V ISA extensions, and virt-like peripheral requirements, then run broader Web/Context7/DeepWiki research, `moon bench`, tuning, and MoonBit refactoring when enough implementation has accumulated or a functional/performance regression suggests it. Avoid long runs of micro-optimization unless a spec/extension change or functional Linux proof has just been advanced. Prefer console/native Linux probes for routine integration evidence; browser checks are optional per-slice, but the one-minute browser Linux usability baseline remains the performance floor for browser-facing work. Backend choice between `wasm` and `wasm-gc` remains measurement-driven.
- Initial Alpine probing favors `wasm-gc` for the browser default: it produces a smaller artifact and reaches the same initramfs-unpack point faster than plain `wasm`. Plain `wasm` remains available with `BROWSER_TARGET=wasm`.
- Alpine bring-up now uses a practical tiny initramfs profile by default. A static `/init` writes the injected marker through `/dev/kmsg`, then runs `/bin/sh -c 'echo riscv-mbt Alpine shell alive > /dev/kmsg; exec /bin/sh'`. QEMU, riscv-mbt native `xxlong`, and browser `wasm-gc` now reach `riscv-mbt Alpine initramfs ready`, `riscv-mbt Alpine shell alive`, and the BusyBox `/ #` prompt. Browser `wasm-gc` also accepts UART input after the prompt and returns `browser-input-ok` from `echo browser-input-ok`. The browser scheduler now runs 262,144 Linux steps/tick and throttles DOM sync to every 16 ticks; `python3 tools/browser_linux_probe.py --serve-dir _build/browser-demo --alpine-functional-smoke --budget-ms 45000 --wall-timeout 180` is the current functional Linux usability gate and checks `/proc`, `/sys`, file creation/readback, directory creation, pipe/grep, `uname -m`, `/proc/cpuinfo`, and `linux-functional-ok`. The latest functional smoke after the first vector subtract slice reached the marker at 360,710,144 guest steps and `wall=0:52.04` on this host.
- The latest console/native Alpine probe after the first vector min/max slice reached the BusyBox `/ #` prompt with `moon run --target native cmd/alpine_probe xxlong`: `outcome=alpine-shell-prompt`, `steps=357000000`, `contains_linux_version=true`, `contains_run_init=true`, and `contains_alpine_shell_prompt=true`.
- Host Wasm SIMD / `v128` is not used yet. The current guest `V` implementation interprets RISC-V vector operations with scalar MoonBit register-element helpers. MoonBit 0.10 introduced an experimental built-in `V128` type, but the official release notes still describe efficient standard-library operations as future work, so any `v128` experiment should remain measured and isolated before it touches the Linux-facing execution path. `moon bench` now includes `vector_add_lmul2_loop_100k_steps` as the scalar baseline for that work; the first baseline measured `31.18 ms +/- 304.25 us`.

## Read Next

- [Roadmap](roadmap.md)
- [Implementation Notes](guides/implementation-notes.md)
- [Browser Wasm Linux Boot milestone](milestones/12-browser-wasm-linux-boot.md)
- [Task 0049](tasks/0049-browser-wasm-smoke-host.md)
- [Task 0050](tasks/0050-browser-runtime-boundary-refactor.md)
- [Task 0051](tasks/0051-browser-linux-artifact-loader.md)
- [Task 0052](tasks/0052-browser-long-run-refactor.md)
- [Task 0053](tasks/0053-browser-one-hart-linux-boot.md)
- [Task 0054](tasks/0054-browser-linux-observability-refactor.md)
- [Task 0055](tasks/0055-browser-plain-wasm-backend.md)
- [Task 0056](tasks/0056-simmerv-inspired-cache-performance.md)
- [Task 0057](tasks/0057-moonbit-refactoring-pre-0048.md)
- [Task 0058](tasks/0058-alpine-rootfs-browser-boot.md)
- [Performance milestone](milestones/10-verification-debug-performance.md)
- [Extensions milestone](milestones/09-extensions-a-fd-v-h.md)
- [Task 0018](tasks/0018-extensions-a-fd-v-h.md)
- [Task 0048](tasks/0048-broader-vector-memory-and-lmul-slice.md)
- [Task 0047](tasks/0047-masked-and-broader-vector-execute-slice.md)
- [Task 0046](tasks/0046-first-vector-memory-slice.md)
- [Task 0045](tasks/0045-first-vector-arithmetic-slice.md)
- [Task 0044](tasks/0044-vsetvl-and-first-vector-execute-slice.md)
- [Task 0043](tasks/0043-vector-extension-evaluation.md)
- [Task 0042](tasks/0042-post-fd-closure.md)
- [Task 0041](tasks/0041-d-extension-bring-up.md)
- [Task 0009](tasks/0009-rv32-supervisor-sv32.md)
- [ADR 0006](adr/0006-browser-wasm-linux-boot-goal.md)
- [ADR 0007](adr/0007-browser-plain-wasm-backend.md)
- [ADR 0008](adr/0008-browser-wasm-gc-for-alpine-boot.md)
- [ADR 0009](adr/0009-bounded-uop-cache-safety.md)
- [ADR 0001](adr/0001-rv32i-first.md)
- [ADR 0005](adr/0005-post-linux-compatibility-profile.md)
- [ADR 0003](adr/0003-milestone-spine.md)
