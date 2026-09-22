# Current State

## Current Milestone

- `v1.0 closure` under [ADR 0010](adr/0010-v1-completion-boundary.md)
- `v1.0` means: `RV64GC` (`RV64IMAFDC_Zicsr_Zifencei`) gated by every applicable official `riscv-tests` row, OpenSBI plus a `virt`-like platform booting Linux natively (one hart and SMP), an Alpine rootfs reaching userspace natively and in browser Wasm, and a clean build on the pinned MoonBit toolchain
- The 2026-07 progress narrative that used to live here is preserved in [history/2026-07-rv64gc-hardening-notes.md](history/2026-07-rv64gc-hardening-notes.md)

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
- [Add post-Linux extensions in priority order](tasks/0018-extensions-a-fd-v-h.md) — `done`
- [Bring up scalar `F`](tasks/0040-f-scalar-bring-up.md) — `done`
- [Bring up `D`](tasks/0041-d-extension-bring-up.md) — `done`
- [Close the post-`F/D` phase](tasks/0042-post-fd-closure.md) — `done`
- [Evaluate the first `V` slice](tasks/0043-vector-extension-evaluation.md) — `done`
- [Bring up `vsetvl*` and the first vector execute slice](tasks/0044-vsetvl-and-first-vector-execute-slice.md) — `done`
- [Implement the first vector arithmetic slice](tasks/0045-first-vector-arithmetic-slice.md) — `done`
- [Implement the first vector memory slice](tasks/0046-first-vector-memory-slice.md) — `done`
- [Implement the first masked and broader vector execute slice](tasks/0047-masked-and-broader-vector-execute-slice.md) — `done`
- [Implement the next broader vector memory and `LMUL` slice](tasks/0048-broader-vector-memory-and-lmul-slice.md) — `done`
- [Move the browser smoke host to Wasm](tasks/0049-browser-wasm-smoke-host.md) — `done`
- [Refactor the browser runtime boundary](tasks/0050-browser-runtime-boundary-refactor.md) — `done`
- [Add a browser Linux artifact loader](tasks/0051-browser-linux-artifact-loader.md) — `done`
- [Refactor browser long-run behavior](tasks/0052-browser-long-run-refactor.md) — `done`
- [Boot Linux on one hart in browser Wasm](tasks/0053-browser-one-hart-linux-boot.md) — `done`
- [Refactor browser Linux observability](tasks/0054-browser-linux-observability-refactor.md) — `done`
- [Move the browser host to the plain Wasm backend](tasks/0055-browser-plain-wasm-backend.md) — `done`
- [Add simmerv-inspired cache performance improvements](tasks/0056-simmerv-inspired-cache-performance.md) — `done`
- [Refactor MoonBit execution surfaces before the next vector slice](tasks/0057-moonbit-refactoring-pre-0048.md) — `done`
- [Boot an Alpine rootfs in browser Wasm](tasks/0058-alpine-rootfs-browser-boot.md) — `done`
- [Add a console Alpine Linux probe](tasks/0059-console-alpine-linux-probe.md) — `done`
- [Choose the full-rootfs I/O strategy](tasks/0060-full-rootfs-io-strategy.md) — `done`
- [Harden full-rootfs Linux usability](tasks/0061-full-rootfs-usability-hardening.md) — `done`
- [Harden rootfs init and service usability](tasks/0062-rootfs-init-service-usability.md) — `done`
- [Complete RV64GC spec compliance](tasks/0063-rv64gc-spec-compliance.md) — `done`

## Next Task

- Next: publish `v1.0`. Push `main` (it is several hundred commits ahead of `origin/main`), confirm the CI and GitHub Pages workflows are green on the pinned toolchain, then tag `v1.0.0`.
- Task 0063 is `done`: all applicable official `rv64ui`/`um`/`ua`/`uc`/`uf`/`ud`/`mi`/`si` rows are `gating` (144 rows), with `rv64mi/breakpoint` and `rv64mi/pmpaddr` recorded as inapplicable.
- After `v1.0.0`: start from the post-`v1.0` backlog in [roadmap.md](roadmap.md); do not reopen closed tasks.

## Toolchain Contract

- MoonBit is pinned in `moonbit-version` (installed locally through `moonup`); CI installs exactly that version.
- `moon.mod` dependency versions move with the toolchain pin. `moonbitlang/async` is only used by the native host commands and tests, not by the emulator core.
- The validation sequence is `moon check`, `moon test`, `moon fmt`, `moon info --target native`, and `git diff --check`; all must be clean before a commit.

## Known Blockers

- Local `moon test` expects official `riscv-tests` ELF artifacts under `_build/riscv-tests-src/isa` and `_build/riscv-tests-src-rv64/isa`; run `./scripts/build-riscv-tests-official.sh` (or the podman variant, which is the only path on hosts without a `riscv64-elf-gcc`) first.
- The Alpine rootfs builder tracks `latest-stable`, so a rebuild picks up whatever kernel and packages Alpine ships that day; the checked-in probes were last validated against the artifacts recorded in Task 0061 and Task 0062.
- The official QEMU cross-check path is RV32-only; an RV64 cross-check is post-`v1.0` backlog.
- Debug Mode / `Sdtrig` and PMP are deliberately not implemented; guests that probe them see the documented trap or zero behavior.

## Read Next

- [Roadmap](roadmap.md)
- [ADR 0010: v1.0 completion boundary](adr/0010-v1-completion-boundary.md)
- [Task 0063](tasks/0063-rv64gc-spec-compliance.md)
- [Implementation Notes](guides/implementation-notes.md)
- [Extensions milestone](milestones/09-extensions-a-fd-v-h.md)
- [Browser Wasm Linux Boot milestone](milestones/12-browser-wasm-linux-boot.md)
- [2026-07 hardening notes](history/2026-07-rv64gc-hardening-notes.md)
