# riscv-mbt

This is a general-purpose RISC-V emulator project built in MoonBit. Linux boot and browser execution are major destination milestones, but the development path is organized around ISA and system-integration milestones starting from `RV32I`.

## Current Checkpoint

- The repo already has an AI-readable operating system in Markdown
- The MoonBit project is initialized
- The `RV32IM` integer core is implemented
  - all branch variants
  - the main `OP-IMM` / `OP` integer operations
  - all `M` extension multiply/divide operations
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

## Next Milestone

- The `RV32IM` core and the official `riscv-tests` execution path are now in a good place, so the next step is [RV32IMC](docs/tasks/0006-rv32imc.md)
- After that, the path continues through `RV32IMC + Zicsr + Zifencei` toward the first practical standalone checkpoint
- `Linux boot` is treated as a system-integration gate built from privileged support + MMU + SBI + device model work, not just as “more ISA coverage”

## Read Next

- [Current State](docs/current.md)
- [Roadmap](docs/roadmap.md)
- [Implementation Notes](docs/guides/implementation-notes.md)
- [RV32IMC Milestone](docs/milestones/03-rv32imc.md)
- [Agent Guide](AGENTS.md)

## Common Commands

```bash
make smoke
make ci-local
make rv32ui-qemu
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
moon run cmd/c_sample
```
