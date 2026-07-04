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
- Medium term: implement a contract-shaped `virtio,mmio` `virtio-blk` device for the
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
- Design the Linux-visible `virtio,mmio` block surface:
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
- Added the first `virtio,mmio` `virtio-blk` contract slice: an optional
  machine config, MMIO identity/status/queue register surface, shared device
  state across SMP harts, and an optional DTB `virtio,mmio` node. Request queue
  processing and disk-image backing remain the next implementation work.
- Added the first read-only request queue path: `QueueNotify` now consumes split
  virtqueue available entries, copies sector data from `Runner` disk backing to
  a writable data descriptor, writes the status byte, advances the used ring,
  and raises PLIC source 1. This is still a contract slice, not yet a full-rootfs
  Linux proof: disk image loading and a real Alpine rootfs boot are next.
- Added `scripts/build-alpine-rootfs-image.sh` to create a raw ext4 Alpine
  minirootfs image under `_build/alpine-rootfs-riscv64.ext4`.
- Extended the Alpine initramfs builder so it derives the boot kernel and
  virtio modules from Alpine `linux-lts`, keeps the tiny initrd usable for
  console probing, and emits `_build/minimal-alpine-virtio.dtb` with a
  `virtio,mmio` block node.
- Added `cmd/alpine_probe` options for `--dtb`, `--initrd`, and
  `--virtio-blk-disk`, so the console/native probe can exercise the raw rootfs
  backing without changing the default tiny-initrd path.
- Added the `VIRTIO_F_VERSION_1` feature bit and dynamic capacity reporting
  from the loaded disk image. Without that feature Linux rejected the version 2
  MMIO device with `New virtio-mmio devices (version 2) must provide
  VIRTIO_F_VERSION_1 feature!`.
- Current Linux proof: with `_build/minimal-alpine-virtio.dtb` and
  `_build/alpine-rootfs-riscv64.ext4`, the Alpine console/native probe reaches
  kernel block-device enumeration:
  `virtio_blk virtio0: [vda] 131072 512-byte logical blocks (67.1 MB/64.0 MiB)`.
  The proof is not yet a mounted-rootfs proof. A userspace command marker did
  not complete by 600,000,000 guest steps, so the next work should focus on
  post-enumeration block request progress and interrupt behavior before claiming
  ordinary full-rootfs use.
- Fixed the virtio-blk interrupt path so PLIC claimability is reflected into
  CPU external interrupt pending bits for virtio-blk, not just UART. The
  regression now checks that a completed virtio-blk read sets `mip.MEIP/SEIP`.
- Generalized virtio-blk read requests from one data descriptor to a normal
  split-virtqueue chain with one or more writable data descriptors followed by
  a final writable status descriptor. The regression now uses two data
  descriptors to cover scatter-gather reads.
- Added `cmd/alpine_probe --rootfs-smoke`. It defaults to
  `_build/minimal-alpine-virtio.dtb` and `_build/alpine-rootfs-riscv64.ext4`,
  loads the virtio and ext4 modules, mounts `/dev/vda` read-only as ext4, and
  emits `rootfs-mount-ok` from BusyBox inside the mounted rootfs. The probe uses
  octal `printf` markers so command echo cannot satisfy the expectation.
- The Alpine initramfs builder now expands copied kernel modules to `.ko`
  files and rewrites `modules.dep` accordingly. This avoids BusyBox `modprobe`
  passing compressed `.ko.gz` files to the kernel and producing
  `Invalid ELF header magic` logs.
- Current mounted-rootfs proof:
  `moon run --target native cmd/alpine_probe xlong --rootfs-smoke` reaches
  `outcome=console-command`, `shell_expect_seen=true`, `steps=603000000`,
  `EXT4-fs (vda): mounted filesystem ... ro`, and `rootfs-mount-ok`.
  This proves read-only rootfs block I/O and execution of a binary from the
  mounted rootfs. It is still not a full root handoff: Linux is still booted
  through the tiny initramfs shell, so the next step is an initramfs-driven
  `switch_root` or an equivalent direct-root boot path.
- Added `cmd/alpine_probe --switch-root-smoke` and the `switch_root` BusyBox
  applet to the tiny initramfs. This probe mounts `/dev/vda` read-only, mounts
  `/proc`, `/sys`, and `/dev` under the new root, then runs
  `switch_root /mnt/root /bin/busybox sh -c ...` so the final marker is emitted
  after the root handoff.
- Current root-handoff proof:
  `moon run --target native cmd/alpine_probe xlong --switch-root-smoke` reaches
  `outcome=console-command`, `shell_expect_seen=true`, `switch_root_smoke=true`,
  `steps=612000000`, `EXT4-fs (vda): mounted filesystem ... ro`, and
  `switch-root-ok`. This is stronger than the mounted-rootfs proof because the
  command after `switch_root` runs from the mounted Alpine rootfs. It still does
  not prove the ordinary Alpine init path; the next work should try
  `switch_root /mnt/root /sbin/init` or an equivalent direct-root boot command
  and then validate normal userspace after init starts.
- First ordinary-init handoff attempt:
  `switch_root /mnt/root /sbin/init` mounts the virtio-backed ext4 rootfs and
  hands control to Alpine's init, but does not reach `Welcome to Alpine` within
  1,000,000,000 guest steps. The kernel reports
  `init[1]: unhandled signal 11` in `ld-musl-riscv64.so.1`, with
  `badaddr: 0000000000000308`, then panics with
  `Attempted to kill init! exitcode=0x0000000b`.
- This moves the active blocker past block I/O and root handoff. The next
  implementation slice should isolate why ordinary dynamically linked Alpine
  userspace or BusyBox init faults after `switch_root`, preferably with a
  smaller command/rootfs reproducer before adding broad ISA or RVV coverage.
- The generated rootfs now replaces Alpine minirootfs' default `openrc`
  inittab with a BusyBox-init inittab that mounts `/proc`, `/sys`, `/dev`,
  `/run`, and `/tmp`, then starts a serial getty on `ttyS0`. The minirootfs
  does not include `/sbin/openrc`, so keeping the default inittab was not a
  straightforward rootfs contract even though it was not the immediate crash
  cause.
- `busybox init` as a child process from the initramfs shell reaches
  `init: must be run as PID 1` and returns to the shell. That narrows the crash
  away from generic BusyBox/musl execution and toward the PID 1 handoff path.
- Sv39 translation now uses hardware-managed A/D-bit behavior instead of
  faulting when a leaf PTE has `A=0` or, for stores, `D=0`. This is a Linux-path
  correctness improvement, but it does not fix the Alpine init crash.
- Temporary fault diagnostics showed that the kernel panic's faulting PC
  executes a stale fetched instruction word (`0x30233423`, decoded as an
  `sd` using `rs1=x6` and `imm=776`) while Linux's fault dump reads the current
  instruction bytes at that same userspace PC (`0xeed43423`, `sd a3,-280(s0)`).
  The next slice should focus on user executable fetch coherence or translation
  provenance, not on broad ISA coverage.
