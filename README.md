# riscv-mbt

This is a general-purpose RISC-V emulator project built in MoonBit. Linux boot and browser execution are major destination milestones, but the development path is organized around ISA and system-integration milestones starting from `RV32I`.

## Current Checkpoint

- The repo already has an AI-readable operating system in Markdown
- The MoonBit project is initialized
- The `RV32IMC` integer core is implemented
  - all branch variants
  - the main `OP-IMM` / `OP` integer operations
  - all `M` extension multiply/divide operations
  - the current compressed integer subset with mixed-width fetch/decode
  - byte / halfword / word load-store
  - `JAL` / `JALR`
  - representative decode / execute / integration tests
- The upstream `riscv-tests` official build path is maintained through `scripts/build-riscv-tests-official.sh`
- There is also a `podman` path for pinning the official build toolchain
- A linked-address ELF loader is in place, so official binaries can be loaded at their linked addresses
- A minimal `env/p` substrate exists, and the official `rv32ui-p-*` gating subset is green
- `moon test` reads built official ELF files directly and runs the official subset
- The same official `rv32ui-p-*` gating subset can be cross-checked in `qemu-system-riscv32`
- GitHub Actions builds the official `riscv-tests` subset and runs `moon test`
- A freestanding `RV32I` C sample can also be built and run
- A built upstream `*-p-*` survey currently reports `122 total / 51 pass`, with `rv32ui`, `rv32um`, and the current `rv32uc` coverage passing
- The official always-green subset now includes `rv32ui/fence_i`
- Minimal M-mode is now complete:
  - trap entry and trap return semantics are explicit
  - `mip` exists as machine-state storage
  - the machine CSR contract is explicit in code and tests
- Practical RV64 core stabilization is now complete:
  - internal architectural state is RV64-capable
  - RV64I sign-extension invariants and RV64M `*W` regressions are covered
  - the current `C`, `Zicsr`, and `Zifencei` surface has explicit RV64 carry-forward regressions
  - `Runner.load_elf(...)` supports both `ELF32` and `ELF64`
  - official `rv64ui` / `rv64um` survey plumbing is in place
- Linux boot platform integration is now complete:
  - `S`-mode, delegation, and `SRET` are in place
  - `Sv39`, `SFENCE.VMA`, and `MPRV` are covered
  - OpenSBI and a virt-like platform are integrated
  - the Linux boot ABI and SMP follow-through are implemented on the current path
- The first browser host artifact now exists:
  - `cmd/browser` is a thin JS-target host over the shared core
  - `./scripts/build-browser-demo.sh` assembles `_build/browser-demo/`
  - the current smoke scope is serial output, UART input, and minimal step/run/reset controls
- Scalar `F` and `D` are now in place on the post-Linux path:
  - the current implementation is explicitly constrained to host IEEE arithmetic
  - only the default rounding mode is supported
  - `fflags` is visible state, not yet full exception-flag conformance

## Next Milestone

- The repo has finished the Linux boot platform integration milestone
- The browser delivery milestone is also complete:
  - the hosting decision is fixed on `GitHub Pages`
  - the public smoke demo is live at `https://gaato.github.io/riscv-mbt/`
- The post-Linux compatibility target is now fixed as `RV64 Linux Profile v1`
- The first required compatibility gap for that profile, `F/D`, is now closed in the repo docs and implementation
- The mainline next step is [Extensions In Priority Order](docs/milestones/09-extensions-a-fd-v-h.md)
- The next concrete task is [0043 evaluate the first `V` slice](docs/tasks/0043-vector-extension-evaluation.md)
- The optional side branch remains [RV32 supervisor + Sv32](docs/tasks/0009-rv32-supervisor-sv32.md)

## Read Next

- [Current State](docs/current.md)
- [Roadmap](docs/roadmap.md)
- [Implementation Notes](docs/guides/implementation-notes.md)
- [Extensions Milestone](docs/milestones/09-extensions-a-fd-v-h.md)
- [Task 0018](docs/tasks/0018-extensions-a-fd-v-h.md)
- [Task 0043](docs/tasks/0043-vector-extension-evaluation.md)
- [ADR 0005](docs/adr/0005-post-linux-compatibility-profile.md)
- [Agent Guide](AGENTS.md)

## Common Commands

```bash
make smoke
make ci-local
make rv32ui-qemu
make rv32uc-survey
make c-sample
```

## Direct Commands

```bash
moon check
moon test
moon run cmd/main
./scripts/build-riscv-tests-official.sh
./scripts/build-riscv-tests-official-in-podman.sh
./scripts/cross-check-official-rv32ui-with-qemu.pl
./scripts/build-rv32i-c-sample.sh
./scripts/run-rv32i-c-sample.sh
./scripts/build-browser-demo.sh
moon run cmd/c_sample
moon run cmd/official_survey -- rv32uc
moon run cmd/official_survey -- rv64ui
moon run cmd/official_survey -- rv64um
```
