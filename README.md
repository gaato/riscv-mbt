# riscv-mbt

A general-purpose RISC-V emulator written in MoonBit. It grew milestone by milestone from `RV32I` to an `RV64GC` core that boots OpenSBI, Linux, and an Alpine rootfs, both natively and in the browser through Wasm.

## What It Does

- Emulates `RV64GC` (`RV64IMAFDC_Zicsr_Zifencei`) with M/S/U privilege modes, `Sv39`, and the CSR/trap contract needed by OpenSBI and Linux
- Boots OpenSBI and Linux on a `QEMU virt`-like platform (UART, CLINT, PLIC, `virtio-blk`), on one hart or with SMP
- Boots an Alpine rootfs to userspace natively (`cmd/alpine_probe`) and in browser Wasm (`cmd/browser`)
- Is gated by the official `riscv-tests` binaries: every applicable `rv64ui`/`rv64um`/`rv64ua`/`rv64uc`/`rv64uf`/`rv64ud`/`rv64mi`/`rv64si` row in `tools/riscv-tests-manifest.tsv` runs under `moon test`
- Carries a partial, experimental `V` implementation that is not part of the supported baseline
- Publishes a browser demo at `https://gaato.github.io/riscv-mbt/` from `main` through GitHub Actions

## Status

- No version tags; `moon.mod` stays `0.1.0` until a mooncakes release ([ADR 0011](docs/adr/0011-no-version-tags-and-new-direction.md))
- Current direction: [Milestone 13](docs/milestones/13-fast-observable-networked-linux.md), a fast, observable, network-connected Linux environment (execution-path performance, a GDB remote stub, `virtio-net` plus a MoonBit user-mode NAT stack); [docs/current.md](docs/current.md) tracks the open task
- Backlog (vector FP and reductions, `H`, `riscv-arch-test`, PMP, OpenRC daemon supervision, and so on) lives in [docs/roadmap.md](docs/roadmap.md)
- Not implemented on purpose: Debug Mode / `Sdtrig`, PMP, `H`, `Zb*`, `Zfh`

## Toolchain

- MoonBit is pinned in `moonbit-version`; install it with `moonup install "$(cat moonbit-version)"` or let the official installer take the version as its argument. CI uses the same pin
- Official `riscv-tests` ELFs are built by `./scripts/build-riscv-tests-official.sh`; on hosts without `riscv64-elf-gcc`, use `./scripts/build-riscv-tests-official-in-podman.sh`
- Linux, OpenSBI, and Alpine artifacts are produced by `scripts/build-alpine-*.sh` from official Alpine `latest-stable` packages

## Read Next

- [Current State](docs/current.md)
- [Roadmap](docs/roadmap.md)
- [ADR 0011: no version tags, next direction](docs/adr/0011-no-version-tags-and-new-direction.md)
- [Implementation Notes](docs/guides/implementation-notes.md)
- [Milestone 13: Fast, Observable, Networked Linux](docs/milestones/13-fast-observable-networked-linux.md)
- [Browser Wasm Linux Boot Milestone](docs/milestones/12-browser-wasm-linux-boot.md)
- [Extensions Milestone](docs/milestones/09-extensions-a-fd-v-h.md)
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
python3 tools/browser_linux_probe.py --serve-dir _build/browser-demo --alpine-interactive-smoke --budget-ms 30000 --wall-timeout 180
moon run cmd/c_sample
moon run cmd/official_survey -- rv32uc
moon run cmd/official_survey -- rv64ui
moon run cmd/official_survey -- rv64um
```
