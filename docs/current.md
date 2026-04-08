# Current State

## Current Milestone

- `RV64 transition`

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
- [Stabilize the practical RV64 core](tasks/0011-rv64-practical-core.md) — `doing`
- [Add S-mode and delegation](tasks/0012-s-mode-and-delegation.md) — `todo`
- [Add Sv39 and SFENCE.VMA](tasks/0013-sv39-and-sfence-vma.md) — `todo`
- [Integrate OpenSBI and a virt-like platform](tasks/0014-opensbi-and-virt-platform.md) — `todo`
- [Meet the Linux boot ABI on one hart](tasks/0015-linux-boot-abi-single-hart.md) — `todo`
- [Add SMP after single-hart boot](tasks/0016-smp-after-single-hart.md) — `todo`
- [Load official `riscv-tests` binaries](tasks/0024-official-riscv-tests-loader.md) — `done`
- [Add minimal `env/p` support](tasks/0025-minimal-env-p-support.md) — `done`
- [Run an official `rv32ui-p-*` subset](tasks/0026-official-rv32ui-runner.md) — `done`
- [Cross-check official `rv32ui-p-*` with a system emulator](tasks/0027-qemu-cross-check-official-rv32ui.md) — `done`
- [Decide the browser demo hosting target](tasks/0021-browser-hosting-decision.md) — `todo`
- [Deploy the first browser smoke demo](tasks/0022-browser-smoke-demo-deploy.md) — `todo`
- [Enable preview deploys for browser work](tasks/0023-browser-preview-deploys.md) — `todo`

## Next Task

- Continue [Task 0011](tasks/0011-rv64-practical-core.md): carry forward the practical RV64 core while keeping MMU, SBI, and platform work separate.

## Known Blockers

- The official QEMU cross-check path currently focuses on the `rv32ui` gating subset. `rv32um`, `rv32uc`, and broader privileged coverage still need follow-up work.
- Local `moon test` now expects build artifacts under `_build/riscv-tests-src/isa`; run `./scripts/build-riscv-tests-official.sh` first if they are missing.
- The built upstream `*-p-*` survey currently stands at `122 total / 51 pass`, with `rv32ui`, `rv32um`, and the current `rv32uc` coverage passing; broader extension failures remain out of scope for the current milestone spine.
- Official regression is still RV32-only; RV64 official ELF loading and survey work remain deferred to the practical-core stage.

## Read Next

- [Roadmap](roadmap.md)
- [Implementation Notes](guides/implementation-notes.md)
- [RV64 transition milestone](milestones/06b-rv64-transition.md)
- [Task 0011](tasks/0011-rv64-practical-core.md)
- [Task 0009](tasks/0009-rv32-supervisor-sv32.md)
- [ADR 0001](adr/0001-rv32i-first.md)
- [ADR 0003](adr/0003-milestone-spine.md)
