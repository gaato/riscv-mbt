# Task 0060: Full Rootfs I/O Strategy

## Background

The Alpine tiny initramfs path now reaches a BusyBox prompt and can run basic
userspace commands. That proves Linux can execute, but it is still not a
normal root filesystem: there is no block device, no mounted persistent root,
and the artifact is intentionally trimmed to keep browser boot practical.

The next Linux-usability work should stop treating broad ISA coverage as the
main queue. ISA work remains important when Linux actually trips over an
illegal instruction, trap, or documented RISC-V/Linux requirement, but full
rootfs progress needs an I/O decision first.

## Sources

- Linux RISC-V architecture documentation index: <https://docs.kernel.org/arch/riscv/index.html>
- Linux RISC-V boot requirements: <https://docs.kernel.org/arch/riscv/boot.html>
- Linux virtio driver API overview: <https://docs.kernel.org/driver-api/virtio/virtio.html>
- OASIS virtio specification: <https://docs.oasis-open.org/virtio/virtio/v1.2/virtio-v1.2.html>

## Decision

Use two layers:

- Short term: keep the tiny/full initrd path as the fast functional gate.
  Expand console/native command proofs here because the current emulator
  already supports RAM, DTB initrd handoff, UART, CLINT, and PLIC well enough.
- Medium term: implement a minimal `virtio,mmio` `virtio-blk` device for the
  real full-rootfs path. A normal Alpine root filesystem should eventually be
  mounted as a block device instead of being packed entirely into initramfs.

`initrd` expansion is not the final full-rootfs answer. It is still useful for
raising the Linux userspace proof level while `virtio-blk` is designed and
implemented.

## Why Not Initrd Only

- It hides the block I/O surface Linux normally needs for a full rootfs.
- It scales poorly for larger root filesystems and package-manager workflows.
- It cannot prove the emulator's DMA-like device behavior, interrupt delivery,
  or Linux block stack compatibility.

## Why Virtio-Block Next

- The current virt-like platform already models MMIO devices and PLIC routing.
- Linux has standard virtio drivers, and a DTB `virtio,mmio` node is the
  narrowest path that avoids PCI while still exercising a real block stack.
- The OASIS virtio spec models virtqueues as descriptor rings in guest memory;
  that maps naturally onto the emulator's existing physical memory helpers.

## Work

- Add `cmd/alpine_probe --functional-smoke` as the console/native counterpart
  to the browser Alpine functional smoke.
- Keep `scripts/build-alpine-initramfs.sh` as the short-term initrd artifact
  generator and allow `ALPINE_INITRD_PROFILE=full` experiments.
- Design the smallest `virtio,mmio` block surface:
  - one MMIO transport window
  - one request virtqueue
  - read-only disk image first
  - PLIC interrupt source after used-ring updates
  - DTB node with `compatible = "virtio,mmio"`
- Add a raw Alpine rootfs image fixture once the block device exists.
- Prefer Linux-driven failures over speculative ISA work when choosing the next
  compatibility slice.

## Acceptance Criteria

- Console/native functional smoke proves `/proc`, `/sys`, file operations,
  shell pipe/grep, `uname -m`, and `/proc/cpuinfo` without the browser.
- `docs/current.md` names the I/O strategy and points future agents here before
  resuming RVV backlog work.
- A follow-up task can start `virtio-blk` implementation without re-deciding
  whether initrd-only is sufficient.

## Related Milestones

- Verification, Debug, And Performance
- Browser Wasm Linux Boot
- Extensions: A, F/D, V, H

## Dependencies

- [Task 0058](0058-alpine-rootfs-browser-boot.md)
- [Task 0059](0059-console-alpine-linux-probe.md)

## Status

- `doing`

## Progress Notes

- Initial strategy selected: initrd remains the short-term usability gate;
  `virtio,mmio` `virtio-blk` is the full-rootfs path.
- Added `cmd/alpine_probe --functional-smoke` as the console/native functional
  Linux proof. Validation reached `outcome=console-command`, `steps=362000000`,
  `functional_smoke=true`, `shell_expect_seen=true`, and
  `linux-functional-ok` through the expected marker path.
