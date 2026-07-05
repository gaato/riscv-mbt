# Task 0061: Full Rootfs Usability Hardening

## Background

Task 0060 decided the I/O strategy and then grew into the first practical
full-rootfs implementation: `virtio,mmio` `virtio-blk`, a raw Alpine ext4
rootfs, initramfs-driven root handoff, writable rootfs probes, BusyBox applet
coverage, package installation, and package persistence.

The next work should treat that path as the baseline and harden ordinary Linux
usability. This is not a broad ISA backlog task. New ISA work belongs here only
when a real Linux command, official Linux/RISC-V requirement, or observed trap
shows it is needed.

## Scope

- Keep console/native Alpine rootfs probes as the primary integration surface.
- Prefer `--auto-root-handoff` for new rootfs usability proofs so success does
  not depend on a serial-injected `switch_root`.
- Keep the standard `/sbin/apk` command as the package-manager surface. The
  current rootfs maps it to the static apk copy and preserves the original
  dynamic binary as `/sbin/apk.dynamic` for loader/performance diagnostics.
- Preserve host-image persistence as the proof that rootfs writes survive
  emulator runs.
- Avoid repeating long probes without a new question to answer. If a run is
  expected to be long, add or use telemetry that makes the result actionable.

## Work

- Promote auto-root proofs where the existing evidence still relies on the
  older serial-command-driven root handoff.
- Re-run package persistence through the standard `/sbin/apk` command and, if
  practical, through auto-root handoff.
- Keep dynamic `/sbin/apk.dynamic` as a focused loader/library-read diagnostic;
  do not block package-manager usability on that path while `/sbin/apk` works.
- Add shorter diagnostics or reusable harnesses before adding more long Alpine
  probes.
- Record Linux-driven ISA or platform gaps here when ordinary rootfs commands
  expose them.

## Acceptance Criteria

- `docs/current.md` names this task as the active full-rootfs usability task.
- Standard `/sbin/apk` package installation and dependency resolution are
  proven after initramfs-driven auto-root handoff.
- At least one host-image persistence proof uses the current standard `/sbin/apk`
  command path, or the remaining persistence gap is explicitly recorded as the
  next concrete task.
- New long probes are tied to a specific usability or correctness question and
  record enough counters/output to guide the next implementation step.

## Status

- `doing`

## Progress Notes

- Starting point: auto-root standard-command dependency installation already
  works. `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --post-init-apk-local-deps-smoke --post-init-command-step-budget 160000000`
  reaches `outcome=console-command`, `auto_root_handoff=true`,
  `shell_command_sent=false`, and `post-init-apk-local-deps-ok` at
  797,000,000 guest steps. The run installs `iputils` through standard
  `/sbin/apk`, resolves local repository dependencies, verifies package DB
  entries, checks `bin/ping`, and runs `/bin/ping -V`.
- Auto-root package persistence now uses the current standard `/sbin/apk`
  command path. After copying `_build/alpine-rootfs-riscv64.ext4` to
  `_build/alpine-rootfs-riscv64-apk-auto-root-persist-probe.ext4`,
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-apk-auto-root-persist-probe.ext4 --post-init-command-step-budget 180000000 --post-init-apk-persistence-write-smoke --write-back-virtio-blk-disk`
  reaches `outcome=console-command`, `auto_root_handoff=true`,
  `shell_command_sent=false`, `post_init_apk_persistence_write_smoke=true`,
  `post_init_command_index=2`, and `apk-persistence-write-ok` at
  719,000,000 guest steps. The run writes the mutated virtio-blk image back to
  the host only after the guest-visible success marker.
- Rebooting that saved image with
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-apk-auto-root-persist-probe.ext4 --post-init-command-step-budget 120000000 --post-init-apk-persistence-read-smoke`
  reaches `outcome=console-command`, `auto_root_handoff=true`,
  `shell_command_sent=false`, `post_init_apk_persistence_read_smoke=true`,
  `post_init_command_index=1`, and `apk-persistence-read-ok` at
  681,000,000 guest steps after ext4 journal recovery. The UART tail shows
  `/sbin/apk info -e iputils`, `/sbin/apk info -e iputils-ping`,
  `/sbin/apk info -e libcap2`, `bin/ping`, and
  `apk-persistence-read-ok`, proving installed package DB state and package
  file listings survive a host-saved virtio-blk image reboot.
