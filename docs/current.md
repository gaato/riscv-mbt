# Current State

## Current Milestone

- `RV32IM`

## Current Tasks

- [Bootstrap the repo operating system](tasks/0001-bootstrap-operating-system.md) — `done`
- [Implement the RV32I bootstrap subset](tasks/0002-rv32i-bootstrap-subset.md) — `done`
- [Finish remaining RV32I base instruction coverage](tasks/0003-rv32i-complete-base-core.md) — `done`
- [Introduce riscv-tests for RV32I regression](tasks/0004-riscv-tests-integration.md) — `done`
- [Implement RV32IM](tasks/0005-rv32im.md) — `todo`
- [Implement RV32IMC](tasks/0006-rv32imc.md) — `todo`
- [Add Zicsr and Zifencei](tasks/0007-rv32imc-zicsr-zifencei.md) — `todo`
- [Add minimal M-mode](tasks/0008-minimal-m-mode.md) — `todo`
- [Optional RV32 supervisor + Sv32 path](tasks/0009-rv32-supervisor-sv32.md) — `todo`
- [Establish RV64 sign-extension invariants](tasks/0010-rv64-transition.md) — `todo`
- [Stabilize the practical RV64 core](tasks/0011-rv64-practical-core.md) — `todo`
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

- Move on to [Task 0005](tasks/0005-rv32im.md): add the `M` extension while keeping the official `rv32ui-p-*` subset and the QEMU cross-check path green.

## Known Blockers

- The official QEMU cross-check path currently focuses on the `rv32ui` gating subset. `rv32um`, `rv32uc`, and broader privileged coverage still need follow-up work.
- CI rebuilds the official `riscv-tests` subset and fails if [riscv_tests_official_generated.mbt](/home/gaato/repos/github.com/gaato/riscv-mbt/riscv_tests_official_generated.mbt) is stale.

## Read Next

- [Roadmap](roadmap.md)
- [Implementation Notes](guides/implementation-notes.md)
- [RV32IM milestone](milestones/02-rv32im.md)
- [Task 0005](tasks/0005-rv32im.md)
- [ADR 0001](adr/0001-rv32i-first.md)
- [ADR 0003](adr/0003-milestone-spine.md)
