# gaato/riscv_mbt

A RISC-V emulator written in MoonBit.

- `RV64GC` (`RV64IMAFDC_Zicsr_Zifencei`) with M/S/U privilege modes and `Sv39`
- Boots OpenSBI, Linux, and an Alpine rootfs on a `QEMU virt`-like platform
  (UART, CLINT, PLIC, `virtio-blk`), natively and in browser Wasm
- Gated by the official `riscv-tests` binaries under `moon test`

The repository README, current state, and roadmap live at
<https://github.com/gaato/riscv-mbt>. The public API is the `Runner` type
built by `make_runner`; see `pkg.generated.mbti`.
