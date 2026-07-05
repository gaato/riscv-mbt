# Task 0062: Rootfs Init and Service Usability

## Background

Task 0061 proved that the established full-rootfs path can boot through
initramfs-driven auto-root handoff, use the standard `/sbin/apk` command,
install dependency-bearing packages from a local repository, persist package
installation to a host-saved virtio-blk image, and run package-provided
`/bin/ping` against loopback after reboot.

The next usability gap is the init/service boundary. The generated Alpine
rootfs currently uses a deliberately small BusyBox-init inittab with
`/sbin/riscv-mbt-autoshell`; the image does not currently expose a populated
`/etc/init.d` tree or an OpenRC boot path. That is fine for emulator bring-up,
but it is not the same as a more ordinary Alpine service environment.

## Scope

- Keep console/native probes as the primary integration surface.
- Keep `virtio-blk` and auto-root handoff as the baseline rootfs path.
- Treat BusyBox init as the current known-good baseline, not as an accident.
- Decide with evidence whether the next service target should be:
  - a stronger BusyBox-init service/session model, or
  - adding enough OpenRC packages/configuration to boot OpenRC intentionally.
- Do not start broad ISA work unless a concrete init/service command trips an
  illegal instruction, fault, or official Linux/RISC-V requirement.
- Avoid long probes that do not answer a specific init/service question.

## Work

- Inspect the generated rootfs and builder scripts to record the current
  init/service contents.
- Add a console/native probe for one ordinary service-style workflow that is
  meaningful on the current BusyBox-init rootfs.
- If OpenRC is selected, add it as an explicit rootfs-builder option rather
  than silently changing the default known-good boot path.
- Preserve the current auto-root and package persistence proofs while changing
  init/service behavior.

## Acceptance Criteria

- `docs/current.md` names this task as the active full-rootfs usability task.
- The current init/service baseline is documented from the generated image,
  including whether OpenRC files are present.
- At least one new console/native proof exercises init/service behavior beyond
  the autoshell prompt, or the task records a concrete blocker and next step.
- Any long probe records enough output/counters to identify whether the next
  issue is init wiring, rootfs content, storage, syscall behavior, or ISA.

## Status

- `doing`

## Progress Notes

- Current generated rootfs baseline, checked from
  `_build/alpine-rootfs-riscv64.ext4`: `/sbin/init` is a symlink to
  `/bin/busybox`; `/etc/inittab` mounts `proc`, `sysfs`, `devtmpfs`, `/run`,
  and `/tmp`, respawns `/sbin/riscv-mbt-autoshell` on `ttyS0`, and unmounts on
  shutdown; `/etc/init.d` is not present in the image. This confirms the
  current path is BusyBox-init based, not an OpenRC boot.
- Added `cmd/alpine_probe --post-init-service-smoke` as the first
  BusyBox-init service-style proof. The probe creates an init.d-shaped
  `/etc/init.d/riscv-mbt-service`, starts a background process with a pidfile,
  checks `status`, verifies a service log, stops the process, removes the
  pidfile, and cleans up the script/log.
- The first successful auto-root service proof is:
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --post-init-service-smoke --post-init-command-step-budget 120000000`.
  It reaches `outcome=console-command`, `post_init_service_smoke=true`,
  `post_init_command_index=3`, and `post-init-service-ok` at 632,000,000 guest
  steps. The command trace is
  `cmd1:start=590000000,marker=605000000,duration=15000000; cmd2:start=605000000,marker=620000000,duration=15000000; cmd3:start=620000000,marker=632000000,duration=12000000`,
  so the service-style workflow itself is small compared with boot time.
- Service configuration persistence now has a host-image proof pair. After
  copying `_build/alpine-rootfs-riscv64.ext4` to
  `_build/alpine-rootfs-riscv64-service-persist-probe.ext4`, the write half
  runs
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-service-persist-probe.ext4 --post-init-command-step-budget 120000000 --post-init-service-persistence-write-smoke --write-back-virtio-blk-disk`.
  It reaches `outcome=console-command`,
  `post_init_service_persistence_write_smoke=true`,
  `write_back_virtio_blk_disk=true`, and `service-persistence-write-ok` at
  616,000,000 guest steps, writing the mutated image back only after the
  guest-visible success marker.
- Rebooting the saved service image with
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-service-persist-probe.ext4 --post-init-command-step-budget 120000000 --post-init-service-persistence-read-smoke`
  reaches `outcome=console-command`,
  `post_init_service_persistence_read_smoke=true`,
  `post_init_command_index=1`, and `service-persistence-read-ok` at
  618,000,000 guest steps after ext4 journal recovery. The UART tail shows the
  persisted `/etc/init.d/riscv-mbt-service`, `service-started` from the script
  and runtime log, successful `status`, `stop`, pidfile removal, and
  `service-persistence-read-ok`.
