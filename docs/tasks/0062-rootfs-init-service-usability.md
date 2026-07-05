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
- OpenRC is now an explicit optional rootfs-builder path rather than a silent
  default change. `scripts/build-alpine-rootfs-image.sh` accepts
  `ALPINE_SERVICE_PACKAGES` and `ALPINE_APK_EXTRA_REPO_BASE_URLS`, merges the
  configured APKINDEX files for local dependency resolution, and downloads each
  selected package from the repository that actually contains it. This keeps the
  known-good BusyBox-init rootfs baseline intact while allowing service-manager
  experiments to be built as separate images.
- The OpenRC image builder path exposed a real package-resolution bug:
  `openrc` depends on the virtual dependency `ifupdown-any`, while Alpine's
  `busybox-ifupdown` provides it as `p:ifupdown-any` without an `=` suffix. The
  local APKINDEX provider resolver now accepts both versioned and unversioned
  provides, so an image built with
  `ALPINE_SERVICE_PACKAGES=openrc ALPINE_APK_EXTRA_REPO_BASE_URLS=https://dl-cdn.alpinelinux.org/alpine/latest-stable/community/riscv64 ALPINE_ROOTFS_IMAGE=_build/alpine-rootfs-riscv64-openrc-repo.ext4 ./scripts/build-alpine-rootfs-image.sh`
  contains the OpenRC dependency closure, including `busybox-ifupdown`,
  `openrc-user`, and `libcap2`.
- `cmd/alpine_probe --post-init-openrc-install-smoke` is the first explicit
  OpenRC install/surface probe: it installs `openrc` from the local repository
  after auto-root handoff, checks that `/sbin/openrc`, `/bin/rc-status`, and
  `/sbin/rc-update` exist, runs `/sbin/openrc --version`, and separately probes
  `rc-update show`. A direct emulator-side `apk add openrc` run is too heavy
  for the routine development loop, so the next OpenRC slice should move toward
  an OpenRC-prepared rootfs image and keep post-init probes focused on runtime
  behavior rather than reinstalling service-manager packages every time.
- The rootfs builder now has an explicit
  `ALPINE_EXTRACT_LOCAL_REPO_PACKAGES` option for service-manager experiments.
  With `ALPINE_OFFLINE_APK_PACKAGES=''`, `ALPINE_SERVICE_PACKAGES=openrc`,
  `ALPINE_EXTRACT_LOCAL_REPO_PACKAGES=all`, and the Alpine community riscv64
  repository configured as an extra repo, the builder can create
  `_build/alpine-rootfs-riscv64-openrc-surface.ext4` with OpenRC payload files
  already present. This is intentionally a file-surface preparation path, not a
  claim that Alpine's package database and post-install trigger state match a
  normal guest-side `apk add`.
- `cmd/alpine_probe --post-init-openrc-surface-smoke` checks that prepared
  OpenRC images expose `/sbin/openrc`, `/bin/rc-status`, `/sbin/rc-update`,
  `/etc/init.d`, and `/etc/rc.conf`, then runs `/sbin/openrc --version` and
  `rc-update show` without reinstalling packages inside the emulator. This is
  the preferred OpenRC development-loop probe until an intentional OpenRC boot
  path is selected.
- The first successful prepared OpenRC surface proof is:
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-openrc-surface.ext4 --post-init-command-step-budget 80000000 --post-init-openrc-surface-smoke`.
  It reaches `outcome=console-command`,
  `post_init_openrc_surface_smoke=true`, `post_init_command_index=3`, and
  `post-init-openrc-surface-ok` at 619,000,000 guest steps. The command trace
  is
  `cmd1:start=591000000,marker=596000000,duration=5000000; cmd2:start=596000000,marker=606000000,duration=10000000; cmd3:start=606000000,marker=619000000,duration=13000000`,
  with a post-init virtio delta of 16 read requests / 26,624 bytes. This proves
  the heavy part was package installation, not the OpenRC command surface
  itself.
- `cmd/alpine_probe --post-init-openrc-service-smoke` now proves OpenRC service
  registration on the prepared image without making OpenRC PID 1. The probe
  writes an `openrc-run` service script, creates `/run/openrc/softlevel`, runs
  `rc-update add riscv-mbt-openrc-service default`, verifies it with
  `rc-update show default`, deletes it from the runlevel, and removes the
  script.
- The first successful OpenRC service-registration proof is:
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-openrc-surface.ext4 --post-init-command-step-budget 80000000 --post-init-openrc-service-smoke`.
  It reaches `outcome=console-command`,
  `post_init_openrc_service_smoke=true`, `post_init_command_index=3`, and
  `post-init-openrc-service-ok` at 636,000,000 guest steps. The command trace is
  `cmd1:start=591000000,marker=607000000,duration=16000000; cmd2:start=607000000,marker=622000000,duration=15000000; cmd3:start=622000000,marker=636000000,duration=14000000`,
  with no post-init virtio reads or writes. A direct `rc-service ... start`
  attempt timed out in the second command window, so actual OpenRC-managed
  start/status/stop remains the next narrower OpenRC blocker rather than a
  reason to keep rerunning long install probes.
- `cmd/alpine_probe --post-init-openrc-action-smoke` narrows that blocker: it
  writes a simple `openrc-run` script whose `start`, `status`, and `stop`
  actions only create/check/remove a marker file, then runs those actions
  through `rc-service --nodeps`. This proves the `rc-service` action-dispatch
  path itself works under the current BusyBox-init rootfs.
- The first successful OpenRC action proof is:
  `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --virtio-blk-disk _build/alpine-rootfs-riscv64-openrc-surface.ext4 --post-init-command-step-budget 80000000 --post-init-openrc-action-smoke`.
  It reaches `outcome=console-command`,
  `post_init_openrc_action_smoke=true`, `post_init_command_index=3`, and
  `post-init-openrc-action-ok` at 722,000,000 guest steps. The command trace is
  `cmd1:start=591000000,marker=606000000,duration=15000000; cmd2:start=606000000,marker=680000000,duration=74000000; cmd3:start=680000000,marker=722000000,duration=42000000`.
  The remaining OpenRC gap is narrower than before: `rc-service` can dispatch
  actions, but daemon-style start/status/stop using a persistent background
  process still needs a separate service-supervision slice.
- After the daemon-style OpenRC timeout, probe growth was deliberately paused
  in favor of emulator-side hardening. The first body-side fix in that pass
  tracks LR/SC reservations in physical-address space: LR.W/LR.D establish a
  reservation, SC.W/SC.D only succeed against a live matching reservation,
  store/AMO operations clear the reservation, and regression tests cover SC.W
  failure without LR plus invalidation by an intervening store. This improves
  the lock/futex-like A-extension surface used by ordinary Linux process
  coordination before rerunning another long OpenRC probe.
