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
  The root cause was an instruction fetch bug at a virtual page boundary:
  a 32-bit instruction at page offset `0xffe` translated only the first halfword
  and then read the second halfword from the next physical address instead of
  translating `pc + 2`.
- The fetch path now translates both halfwords of a 32-bit instruction
  independently, and the regression suite covers the truncated high-half fault
  value. The Sv39 path also tracks page-table pages seen during translation and
  flushes the translation cache when the guest stores to one of those pages.
- Current ordinary-init proof:
  `moon run --target native cmd/alpine_probe xlong --init-smoke` mounts the
  virtio-backed ext4 rootfs, runs `switch_root /mnt/root /sbin/init`, and
  reaches the rootfs-side post-init marker. The previous
  `ld-musl-riscv64.so.1` crash is no longer present.
- The rootfs builder now installs `/sbin/riscv-mbt-autoshell` and starts it on
  `ttyS0` from BusyBox init. This is a direct post-init shell for emulator
  validation, not a claim that login/authentication is complete; the minirootfs
  root account is locked by default.
- Current post-init command proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-smoke` reaches
  `outcome=console-command`, `post_init_command_sent=true`,
  `shell_expect_seen=true`, and `post-init-functional-ok`.
- Added the first virtio-blk write request path (`VIRTIO_BLK_T_OUT`). The
  regression builds a split virtqueue write chain, notifies the device, and
  checks that guest bytes are copied into the disk backing with an OK status
  and used-ring length.
- Current writable-rootfs proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-smoke` now mounts
  the ext4 rootfs as `r/w`, reaches the post-init shell, creates and reads a
  tmpfs file under `/tmp`, creates and reads `/root/riscv-mbt-rootfs-write` on
  the mounted rootfs, runs `sync`, reports `riscv64`, verifies `/proc/mounts` is
  readable, and reaches `post-init-functional-ok` at 643,000,000 guest steps.
- Added `cmd/alpine_probe --post-init-session-smoke`, which sends multiple
  commands through the same post-init UART shell instead of treating one long
  command line as the whole proof. The session writes `alpha`, appends and
  greps `beta`, checks `wc -l`, creates a directory, copies the file, lists and
  greps the copy, and runs `sync`.
- Current post-init session proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-session-smoke`
  reaches `outcome=console-command`, `post_init_command_index=3`,
  `shell_expect_seen=true`, and `post-init-session-ok` at 655,000,000 guest
  steps.
- Added `cmd/alpine_probe --post-init-busybox-smoke` as a broader ordinary
  BusyBox session proof on the mounted Alpine rootfs. It lists applets, runs a
  small text pipeline through `sort`, `uniq`, `sed`, `cut`, `tr`, and `awk`,
  exercises file/link/search behavior with `touch`, `chmod`, `test`, `ln`,
  `readlink`, and `find`, then runs `dd`, `head`, `tail`, `xargs`, `env`, `ps`,
  `date`, `sleep`, and `sync`.
- That standard BusyBox run exposed real CPU-side D-extension gaps, not test
  harness gaps. The Linux/BusyBox faults led to `fcvt.d.w`, `fcvt.d.wu`,
  `fcvt.d.l`, `fcvt.d.lu`, `fcvt.w.d`, `fcvt.l.d`, `fcvt.lu.d`, D
  sign-injection, and D compare support, with decode regressions tied to the
  raw instruction words reported by Linux.
- Current broader BusyBox proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-busybox-smoke`
  reaches `outcome=console-command`, `post_init_command_index=4`,
  `shell_expect_seen=true`, and `post-init-busybox-ok` at 710,000,000 guest
  steps. This proves `awk`, filesystem utilities, `dd`, simple pipelines,
  process/environment inspection, and rootfs writes through the post-init shell.
- Added `cmd/alpine_probe --post-init-command ... --post-init-expect ...` for
  shorter targeted post-init diagnostics after the full rootfs and BusyBox init
  handoff. This keeps the Linux-provided userspace as the test surface while
  avoiding the broader BusyBox smoke for every CPU-side change.
- Current custom-command proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-command "printf 'x:2\ny:5\n' > /root/riscv-mbt-short && awk -F: '{s += \$2} END {print s}' /root/riscv-mbt-short && dd if=/root/riscv-mbt-short of=/root/riscv-mbt-short-dd bs=1 count=4 && sync && printf 'post-init-custom-ok\n'" --post-init-expect post-init-custom-ok`
  reaches `outcome=console-command`, `post_init_command_index=1`,
  `shell_expect_seen=true`, and `post-init-custom-ok` at 625,000,000 guest
  steps.
- Closed the next practical D-extension conversion gap exposed by ordinary C
  double userspace by adding `fcvt.wu.d`. The local unprivileged ISA PDF under
  `docs/specs/riscv-unprivileged.pdf` confirms that RV64 `FCVT.W[U].D`
  sign-extends the 32-bit result; the execute regression now pins that behavior
  for the unsigned-word path.
- Closed the matching practical F-extension gaps before they became the next
  one-instruction-at-a-time Linux failure loop. Single-precision sign injection,
  comparisons, integer-to-single conversions, and single-to-integer conversions
  now decode and execute, with regressions covering RV64 `FCVT.W[U].S`
  sign-extension, sign injection, comparisons, and the `L/LU` conversion forms.
- Floating-point rounding and exception behavior is still intentionally
  practical, not fully architectural. Float arithmetic and integer-to-float
  conversions currently accept static RNE or dynamic RNE; float-to-integer
  conversions accept static RTZ or dynamic RTZ. Other rounding modes trap as
  illegal instructions so the missing modes are visible instead of silently
  producing misleading results.
- Floating-point invalid/overflow/NaN conversion behavior and `fflags` updates
  are not complete. Comparisons return false on NaN, min/max use the current
  canonical-NaN fallback, and out-of-domain float-to-integer conversions still
  need a separate spec-compliance slice for exact clipping and exception flag
  updates. Until that slice exists, Linux-driven ordinary userspace behavior is
  the priority and `fcsr`/`fflags` should not be treated as architecturally
  complete.
- The next full-rootfs usability slice should keep broadening ordinary
  command-session behavior and persistence-oriented checks, but the broad
  BusyBox smoke is too slow for every edit loop. Prefer shorter
  standard-command diagnostics while keeping this broader proof as the stronger
  integration gate.
- Added `cmd/alpine_probe --post-init-storage-smoke` as a storage-oriented
  post-init gate. It creates a larger file on the mounted Alpine rootfs, appends
  a marker, runs `sync`, then copies the file back through `dd`, compares the
  original and copy, checks the tail marker, and emits `post-init-storage-ok`.
  This is still one emulator run rather than host-persistent disk mutation, but
  it exercises the Linux ext4 and virtio-blk read/write paths more directly
  than the applet-oriented BusyBox smoke.
- Added a host-image persistence probe pair:
  `--post-init-persistence-write-smoke --write-back-virtio-blk-disk` creates a
  marker file from rootfs-side Alpine userspace, waits for the guest-visible
  `persistence-write-ok` marker, then writes the mutated virtio-blk backing
  image back to the selected host disk path. A later
  `--post-init-persistence-read-smoke` boot uses the saved image and checks that
  `/root/riscv-mbt-persist` is still present before emitting
  `persistence-read-ok`. This closes the gap between "writes work during one
  emulator run" and "rootfs mutations can survive through the host disk image".
- Current host-persistence proof:
  after copying `_build/alpine-rootfs-riscv64.ext4` to
  `_build/alpine-rootfs-riscv64-persist-probe.ext4`,
  `moon run --target native cmd/alpine_probe xlong --virtio-blk-disk _build/alpine-rootfs-riscv64-persist-probe.ext4 --post-init-persistence-write-smoke --write-back-virtio-blk-disk`
  reaches `outcome=console-command`, `shell_expect_seen=true`,
  `post_init_persistence_write_smoke=true`, and `persistence-write-ok` at
  633,000,000 guest steps. A second boot with
  `moon run --target native cmd/alpine_probe xlong --virtio-blk-disk _build/alpine-rootfs-riscv64-persist-probe.ext4 --post-init-persistence-read-smoke`
  reaches `outcome=console-command`, `shell_expect_seen=true`,
  `post_init_persistence_read_smoke=true`, and `persistence-read-ok` at
  633,000,000 guest steps. The second boot also reports ext4 journal recovery,
  which is expected after the host saves the mutated backing image and then
  boots it again.
- Added `cmd/alpine_probe --post-init-shell-smoke` as a rootfs-side shell
  usability probe. It creates and executes a `#!/bin/sh` script from `/root`,
  checks argument and environment propagation, verifies redirected script
  output, runs a background job with `wait`, checks boolean exit-status flow
  through `false || ...`, and verifies subshell output plus append redirection
  before emitting `post-init-shell-ok`.
- Current shell usability proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-shell-smoke`
  reaches `outcome=console-command`, `post_init_command_index=3`,
  `shell_expect_seen=true`, `post_init_shell_smoke=true`, and
  `post-init-shell-ok` at 662,000,000 guest steps. The UART tail shows the
  script output (`script-arg:arg1`, `script-env:ok`, `script-output`),
  background job output (`background-ok`), exit-status branch
  (`exit-status-ok`), and redirection/subshell output
  (`subshell-ok`, `append-ok`).
- Added `cmd/alpine_probe --post-init-system-smoke` as a rootfs-side system
  administration probe. It checks `/proc/1`, PID 1's BusyBox executable, `ps`,
  root identity via `id`, working-directory changes, directory creation, file
  move/readback, `umask`-controlled permissions, cleanup with `rm`/`rmdir`, and
  `sync` before emitting `post-init-system-ok`.
- Current system administration proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-system-smoke`
  reaches `outcome=console-command`, `post_init_command_index=3`,
  `shell_expect_seen=true`, `post_init_system_smoke=true`, and
  `post-init-system-ok` at 676,000,000 guest steps. The UART tail shows
  `/proc/1` resolving to `/bin/busybox`, `/sbin/init` in `ps`, root identity via
  `id`, moved-file readback, `-rw-------` from `umask 077`, cleanup, and `sync`.
- Added a post-init command step budget to `cmd/alpine_probe`. After a
  rootfs-side post-init command is injected, the probe now reports
  `post-init-command-timeout` instead of waiting for the full `xlong` budget
  when no expected marker appears. This is meant for exploratory diagnostics
  such as package-manager entry checks, where a silent hang should quickly
  become a CPU/userspace investigation target rather than a long wait.
- The post-init command budget is now configurable with
  `--post-init-command-step-budget N`, and the report includes both
  `post_init_command_steps` and `post_init_command_step_budget`. Use a small
  value for exploratory package-manager probes. The budget starts when the
  post-init command is injected, not at boot start, so `apk` or other heavier
  userspace tools classify as command-timeout quickly after they actually
  start running; turn that timeout into a focused CPU/userspace investigation.
- Host-side inspection of `_build/alpine-rootfs-riscv64.ext4` confirms that the
  generated Alpine rootfs contains `/sbin/apk`, `/lib/ld-musl-riscv64.so.1`,
  `/usr/lib/libapk.so.3.0.0`, `/usr/lib/libz.so.1`, and
  `/lib/apk/db/installed`. ELF inspection shows `/sbin/apk` is a dynamic PIE
  using the musl loader, `libapk.so.3.0.0`, `libz.so.1`, and libc. `libapk`
  then pulls in `libssl.so.3`, `libcrypto.so.3`, `libz.so.1`, and libc, with
  immediate binding. That makes `apk --version` a loader/relocation-heavy path,
  not a simple one-binary smoke.
- Added `cmd/alpine_probe --post-init-apk-smoke` as a staged echo-safe
  package-manager diagnostic. Unlike the earlier custom `apk` commands, this
  smoke emits all markers through octal `printf` sequences so command echo
  cannot satisfy the expected marker before the checked step has actually run.
  The stages are: rootfs file presence, dynamic-loader library listing,
  `apk --version`, package DB query, and package file listing.
- Current echo-safe package-manager status:
  `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 20000000 --post-init-apk-smoke`
  reaches `apk-files-ok`, starts
  `/lib/ld-musl-riscv64.so.1 --list /sbin/apk`, prints loader mappings through
  `libssl.so.3`, then reaches `outcome=post-init-command-timeout`,
  `post_init_apk_smoke=true`, `post_init_command_index=2`,
  `post_init_command_steps=629000000`, and
  `post_init_command_step_budget=20000000` at 649,000,000 guest steps before
  `apk-loader-ok`. Package manager usability is not yet echo-safely proven, but
  the missing-file theory is now weaker. The next implementation work should
  treat this as a focused dynamic-loader/relocation progress gap for the `apk`
  dependency stack rather than accepting earlier literal-marker custom command
  results as proof.
- Added virtio-blk read/write request and byte counters to `Runner` and
  `cmd/alpine_probe` output. Future `apk` diagnostics should use these counters
  before adding more long waits: rising read counters point at block/rootfs
  throughput during library loading, while flat counters with advancing steps
  point at CPU-side loader, relocation, syscall, or ISA behavior.
- First staged `apk` rerun with cumulative counters still times out before
  `apk-loader-ok` and reports `virtio_blk=1372 read-req/5182464 read-bytes 1
  write-req/1024 write-bytes`. That is useful but not enough because the count
  includes boot, rootfs mount, and earlier post-init setup. The probe now also
  reports `post_init_command_virtio_delta`, resetting at each post-init command
  injection, so the next `apk` run can distinguish loader-time block I/O from
  CPU-side dynamic-loader, relocation, syscall, or ISA work.
- Staged `apk` rerun with per-command counters again times out before
  `apk-loader-ok`, but now reports
  `post_init_command_virtio_delta=868 read-req/3577856 read-bytes 0 write-req/0
  write-bytes`. The loader path is still actively issuing block reads during
  the 20,000,000-step post-init command window. This weakens the flat
  CPU-spin/illegal-instruction theory for this particular timeout. Next work
  should narrow or speed the dynamic-loader/library-read path before treating
  `apk --version` itself as the failing operation.
- Replaced virtio-blk read descriptor copies with a Bus helper that validates
  the guest range once per descriptor and writes directly into RAM. The previous
  implementation checked guest range and called `store_u8` for every byte,
  which is the wrong shape for the multi-megabyte loader path above. A
  regression now covers the preserved zero-fill behavior for reads past the end
  of the backing image.
- Rerunning the staged `apk` diagnostic after the descriptor-copy cleanup still
  reaches `outcome=post-init-command-timeout`, `post_init_command_index=2`, and
  `post_init_command_virtio_delta=868 read-req/3577856 read-bytes 0 write-req/0
  write-bytes` before `apk-loader-ok`. Do not claim package-manager usability
  or guest-step improvement from this cleanup. The next useful slice is to
  understand why the dynamic loader path generates so many block reads or to
  add a Linux-relevant cache/read-ahead improvement.
- A direct-mapped 512-byte sector cache was tested and deliberately not kept.
  It produced only `virtio_blk_read_cache=4 hits/10118 misses` on the staged
  `apk` diagnostic and still timed out at the same `post_init_command_index=2`
  before `apk-loader-ok`. The observed stream is mostly sequential and
  multi-megabyte, so a tiny sector cache is the wrong shape. Prefer readahead,
  larger chunking, request coalescing, or CPU-side dynamic-loader profiling as
  the next slice.
- The Alpine rootfs builder now downloads `apk-tools-static` from the current
  riscv64 main APKINDEX and installs `/sbin/apk.static` into the generated
  ext4 image by default. This does not fix the dynamic `/sbin/apk` loader path,
  but it gives the rootfs a practical package-database tool that avoids the
  heavy `libapk`/OpenSSL dynamic dependency walk.
- Added `cmd/alpine_probe --post-init-apk-static-smoke` as a separate
  package-manager usability probe. It verifies `/sbin/apk.static`, runs
  `apk.static --version`, queries the installed package DB for `busybox`, lists
  installed package names, and checks the installed `bin/busybox` file entry.
  The markers use octal `printf` sequences, so serial command echo cannot
  satisfy the expected marker.
- Current static package-manager proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 80000000 --post-init-apk-static-smoke`
  reaches `outcome=console-command`, `shell_expect_seen=true`,
  `post_init_apk_static_smoke=true`, `post_init_command_index=4`, and
  `post-init-apk-static-ok` at 741,000,000 guest steps. The run reports
  `post_init_command_virtio_delta=0 read-req/0 read-bytes 0 write-req/0
  write-bytes` for the final file-listing command because the relevant rootfs
  blocks are already cached by Linux at that stage. The UART tail includes
  `apk-tools 3.0.6-r0, compiled for riscv64.`, `busybox`,
  `apk-static-db-ok`, `bin/busybox`, and `post-init-apk-static-ok`.
- Keep the dynamic `--post-init-apk-smoke` as a loader/performance diagnostic,
  not the primary package-manager usability gate. It still times out before
  `apk-loader-ok`, while the static smoke proves a real rootfs-side `apk`
  binary can read the installed DB and package file metadata.
- Extended the rootfs builder with `ALPINE_OFFLINE_APK_PACKAGES`, defaulting to
  `ddate`. It downloads the selected riscv64 main packages from APKINDEX and
  places them under `/root/riscv-mbt-apks/*.apk` without preinstalling them.
  This keeps the generated rootfs able to prove package installation from
  inside Alpine userspace rather than only host-side image construction.
- Tried a heavier offline install probe with `file` plus `libmagic`, but the
  local package add was too slow for the current probe budget: `apk.static`
  began installing `libmagic` and reached 19% before
  `post-init-command-timeout`, with about 4.8 MiB of post-command virtio reads.
  That is useful as a future storage/performance stressor, but it is too large
  for the first install-completion gate.
- Added `cmd/alpine_probe --post-init-apk-install-smoke` using the smaller
  `ddate` package. It verifies that `/usr/bin/ddate` is absent, installs
  `/root/riscv-mbt-apks/ddate.apk` with
  `apk.static --no-network --allow-untrusted --force-non-repository add`, then
  checks `apk info -e ddate`, executes `/usr/bin/ddate`, and emits an
  echo-safe final marker.
- Current offline package-install proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 120000000 --post-init-apk-install-smoke`
  reaches `outcome=console-command`, `shell_expect_seen=true`,
  `post_init_apk_install_smoke=true`, `post_init_command_index=3`, and
  `post-init-apk-install-ok` at 725,000,000 guest steps. The run reports
  `virtio_blk=1485 read-req/5958656 read-bytes 7 write-req/21504 write-bytes`,
  proving the local package add mutates the rootfs through virtio-blk writes.
  The UART tail includes `Installing ddate (0.2.2-r6)`, `OK: 6959 KiB in 17
  packages`, `ddate`, `Today is Sweetmorn, the 1st day of Chaos in the YOLD
  3136`, and `post-init-apk-install-ok`.
- This is still an offline package-file proof, not a full remote repository
  proof. A normal `apk add <name>` from configured repositories needs either
  virtio-net or a deliberate local repository/cache design, and the dynamic
  `/sbin/apk` loader path remains a separate performance diagnostic.
- Added the first local-repository layout experiment: the rootfs builder now
  lays out `APKINDEX.tar.gz` and offline package files both directly under
  `/root/riscv-mbt-apks` and under `/root/riscv-mbt-apks/riscv64`. The arch
  subdirectory matters because `apk.static --repository /root/riscv-mbt-apks`
  looks for `/root/riscv-mbt-apks/riscv64/APKINDEX.tar.gz`.
- Added `cmd/alpine_probe --post-init-apk-local-repo-smoke` to test the
  repository-shaped path with
  `apk.static --no-network --allow-untrusted --repository /root/riscv-mbt-apks add ddate`.
  The first run before the arch subdirectory reported missing
  `riscv64/APKINDEX.tar.gz`. After adding that layout, the probe reached
  `apk-local-repo-files-ok` and started the name-based `apk add ddate`, but did
  not reach `apk-local-repo-add-ok` within the 120,000,000 post-command step
  budget while it was still parsing Alpine's full main APKINDEX.
- The rootfs builder now generates a package-selected local `APKINDEX.tar.gz`
  for `ALPINE_OFFLINE_APK_PACKAGES` instead of copying Alpine's full main
  `APKINDEX.tar.gz` into the guest repository. The earlier single-package
  `ddate` proof shrank the guest local index from the cached 522,190-byte
  upstream index to a 454-byte local tarball containing only the `ddate`
  package record. The builder also stores both file-path compatibility names
  such as `ddate.apk` and repository names such as `ddate-0.2.2-r6.apk`.
- The local repository builder is now dependency-aware. It follows APKINDEX
  package dependencies, strips simple version constraints such as
  `iputils-ping=20250605-r2`, and resolves provided dependencies such as
  `so:libcap.so.2` through `p:` provider records. The default offline package
  set is now `ddate iputils`, which creates a 1,183-byte local APKINDEX and
  includes `iputils`, `iputils-arping`, `iputils-clockdiff`, `iputils-ping`,
  `iputils-tracepath`, `libcap2`, and the already-installed `musl` provider
  package alongside `ddate`.
- Added a 64 KiB virtio-blk read-ahead cache for request-level reads. The cache
  is invalidated when a new host disk image is loaded and whenever the guest
  writes to the backing image, so it does not intentionally change guest-visible
  disk semantics. A regression covers repeated read hits and invalidation after
  disk reload.
- Current repository-style package-manager proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 120000000 --post-init-apk-local-repo-smoke`
  reaches `outcome=console-command`, `shell_expect_seen=true`,
  `post_init_apk_local_repo_smoke=true`, `post_init_command_index=3`, and
  `post-init-apk-local-repo-ok` at 725,000,000 guest steps. The run reports
  `virtio_blk=1488 read-req/5962752 read-bytes 8 write-req/21504 write-bytes`
  and `virtio_blk_read_cache=1350 hits/138 misses`. The UART tail shows
  `apk-local-repo-files-ok`, `Installing ddate (0.2.2-r6)`,
  `apk-local-repo-add-ok`, `ddate`, the expected `ddate` output, and
  `post-init-apk-local-repo-ok`.
- This is still an offline local repository proof, not a virtio-net or remote
  repository proof. It does, however, promote name-based
  `apk.static --repository /root/riscv-mbt-apks add ddate` from a timeout
  diagnostic to a practical package-manager usability gate. The next
  package-manager slice should avoid repeated long probes and either add
  shorter post-init telemetry or move deliberately toward networking/remote
  repository behavior.
- Added `cmd/alpine_probe --post-init-apk-local-deps-smoke` as a stronger
  dependency-resolution package-manager proof. It verifies the local repository
  files for `iputils`, `iputils-ping`, and `libcap2`, confirms that `iputils`
  and `iputils-ping` are not installed yet, runs
  `apk.static --no-network --allow-untrusted --repository /root/riscv-mbt-apks add iputils`,
  then checks `apk info -e iputils`, `apk info -e iputils-ping`,
  `apk info -e libcap2`, the `bin/ping` file listing, and `/bin/ping -V`.
- Current dependency-resolving local-repository proof:
  `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 160000000 --post-init-apk-local-deps-smoke`
  reaches `outcome=console-command`, `shell_expect_seen=true`,
  `post_init_apk_local_deps_smoke=true`, `post_init_command_index=3`, and
  `post-init-apk-local-deps-ok` at 831,000,000 guest steps. The run reports
  `virtio_blk=1522 read-req/6050816 read-bytes 17 write-req/185344 write-bytes`,
  `virtio_blk_read_cache=1383 hits/139 misses`, and only
  `post_init_command_virtio_delta=2 read-req/2048 read-bytes` during the final
  verification command. The UART tail shows `apk-local-deps-files-ok`,
  installation of `libcap2`, `iputils-arping`, `iputils-clockdiff`,
  `iputils-ping`, `iputils-tracepath`, and `iputils`, then
  `apk-local-deps-add-ok`, `iputils`, `iputils-ping`, `libcap2`, `bin/ping`,
  `ping from iputils 20250605`, and `post-init-apk-local-deps-ok`.
- A heavier dependency proof using `file` plus `libmagic` was tried before the
  lighter `iputils` proof. It showed the local repository layout was correct
  and reached `Installing libmagic (5.47-r2)` with progress through 58%, but it
  timed out before completion under a 220,000,000 post-command step budget.
  Keep that as a future storage/package stressor, not the routine
  package-manager gate.
