// Native Alpine boot probe. This command is a host-side integration harness
// for checking Linux/OpenSBI/Alpine progress without involving the browser UI.

///|
let opensbi_path = "_build/opensbi-riscv64-fw_dynamic.bin"

///|
let kernel_path = "_build/linux-kernel-riscv64"

///|
let dtb_path = "_build/minimal-alpine.dtb"

///|
let virtio_dtb_path = "_build/minimal-alpine-virtio.dtb"

///|
let initrd_path = "_build/alpine-initramfs-riscv64.cpio"

///|
let rootfs_image_path = "_build/alpine-rootfs-riscv64.ext4"

///|
let initrd_addr : UInt64 = 0x84000000U.to_uint64()

///|
let fw_dynamic_info_addr : UInt64 = 0x80100000U.to_uint64()

///|
let kernel_entry_addr : UInt64 = 0x80200000U.to_uint64()

///|
let alpine_marker = "riscv-mbt Alpine initramfs ready"

///|
let alpine_shell_marker = "riscv-mbt Alpine shell alive"

///|
let alpine_shell_prompt_marker = "/ #"

///|
let initramfs_unpack_marker_old = "Trying to unpack rootfs image as initramfs"

///|
let initramfs_unpack_marker_new = "Unpacking initramfs..."

///|
let run_init_marker = "Run /init as init process"

///|
let free_initmem_marker = "Freeing unused kernel image"

///|
let free_initrd_marker = "Freeing initrd memory"

///|
let rootfs_marker = "rootfs"

///|
let default_max_steps = 300000000

///|
let drain_interval = 1000000

///|
let csr_sstatus = 0x100

///|
let csr_sie = 0x104

///|
let csr_sepc = 0x141

///|
let csr_scause = 0x142

///|
let csr_stval = 0x143

///|
let csr_sip = 0x144

///|
let csr_satp = 0x180

///|
fn hex(value : UInt64) -> String {
  "0x" + value.to_string(radix=16)
}

///|
fn privilege_name(mode : @riscv.PrivilegeMode) -> String {
  match mode {
    User => "User"
    Supervisor => "Supervisor"
    Machine => "Machine"
  }
}

///|
async fn read_binary(path : String) -> Bytes {
  @fs.read_file(path).binary() catch {
    _ => abort("missing artifact: " + path)
  }
}

///|
fn parse_max_steps(args : Array[String]) -> Int {
  if args.length() >= 2 {
    match args[1] {
      "short" => 19000000
      "medium" => 100000000
      "long" => default_max_steps
      "xxlong" => 600000000
      "xlong" => 1000000000
      _ => default_max_steps
    }
  } else {
    default_max_steps
  }
}

///|
fn parse_arg_value(args : Array[String], flag : String) -> String? {
  if args.length() < 2 {
    return None
  }
  for index in 0..<(args.length() - 1) {
    if args[index] == flag {
      return Some(args[index + 1])
    }
  }
  None
}

///|
fn parse_flag(args : Array[String], flag : String) -> Bool {
  args.any(fn(arg) { arg == flag })
}

///|
fn alpine_functional_smoke_command() -> String {
  // Keep this close to the browser functional smoke so console/native and
  // browser evidence prove the same early-userspace behavior.
  "mount -t proc proc /proc && " +
  "mount -t sysfs sysfs /sys && " +
  "echo file-ok > /tmp/riscv-mbt-file && " +
  "cat /tmp/riscv-mbt-file && " +
  "mkdir -p /tmp/riscv-mbt-dir && " +
  "/bin/sh -c 'echo pipe-ok' | grep pipe-ok && " +
  "uname -m && " +
  "cat /proc/cpuinfo > /tmp/riscv-mbt-cpuinfo && " +
  "printf '\\154\\151\\156\\165\\170\\055\\146\\165\\156\\143\\164\\151\\157\\156\\141\\154\\055\\157\\153\\012'"
}

///|
fn alpine_rootfs_smoke_command() -> String {
  "modprobe virtio_mmio && " +
  "modprobe virtio_blk && " +
  "modprobe ext4 && " +
  "mount -t proc proc /proc && " +
  "mount -t sysfs sysfs /sys && " +
  "mount -t devtmpfs devtmpfs /dev && " +
  "mkdir -p /mnt/root && " +
  "mount -t ext4 -o ro /dev/vda /mnt/root && " +
  "test -x /mnt/root/bin/busybox && " +
  "/mnt/root/bin/busybox printf '\\162\\157\\157\\164\\146\\163\\055\\155\\157\\165\\156\\164\\055\\157\\153\\012'"
}

///|
fn alpine_switch_root_smoke_command() -> String {
  "modprobe virtio_mmio && " +
  "modprobe virtio_blk && " +
  "modprobe ext4 && " +
  "mount -t devtmpfs devtmpfs /dev && " +
  "mkdir -p /mnt/root && " +
  "mount -t ext4 -o ro /dev/vda /mnt/root && " +
  "mount -t proc proc /mnt/root/proc && " +
  "mount -t sysfs sysfs /mnt/root/sys && " +
  "mount -t devtmpfs devtmpfs /mnt/root/dev && " +
  "exec switch_root /mnt/root /bin/busybox sh -c " +
  "\"printf '\\163\\167\\151\\164\\143\\150\\055\\162\\157\\157\\164\\055\\157\\153\\012'; exec /bin/sh\""
}

///|
async fn main {
  let args = @env.args()
  let max_steps = parse_max_steps(args)
  let functional_smoke = parse_flag(args, "--functional-smoke")
  let rootfs_smoke = parse_flag(args, "--rootfs-smoke")
  let switch_root_smoke = parse_flag(args, "--switch-root-smoke")
  let selected_dtb_path = match parse_arg_value(args, "--dtb") {
    Some(path) => path
    None =>
      if rootfs_smoke || switch_root_smoke {
        virtio_dtb_path
      } else {
        dtb_path
      }
  }
  let selected_initrd_path = match parse_arg_value(args, "--initrd") {
    Some(path) => path
    None => initrd_path
  }
  let virtio_blk_disk_path = match parse_arg_value(args, "--virtio-blk-disk") {
    Some(path) => Some(path)
    None =>
      if rootfs_smoke || switch_root_smoke {
        Some(rootfs_image_path)
      } else {
        None
      }
  }
  let selected_virtio_blk_disk_path = match virtio_blk_disk_path {
    Some(path) => path
    None => ""
  }
  let command = if functional_smoke {
    Some(alpine_functional_smoke_command())
  } else if rootfs_smoke {
    Some(alpine_rootfs_smoke_command())
  } else if switch_root_smoke {
    Some(alpine_switch_root_smoke_command())
  } else {
    parse_arg_value(args, "--command")
  }
  let expect = if functional_smoke {
    Some("linux-functional-ok")
  } else if rootfs_smoke {
    Some("rootfs-mount-ok")
  } else if switch_root_smoke {
    Some("switch-root-ok")
  } else {
    parse_arg_value(args, "--expect")
  }
  let fw_bytes = read_binary(opensbi_path)
  let kernel_bytes = read_binary(kernel_path)
  let dtb_bytes = read_binary(selected_dtb_path)
  let initrd_bytes = read_binary(selected_initrd_path)
  let virtio_blk_disk_bytes = match virtio_blk_disk_path {
    Some(path) => Some(read_binary(path))
    None => None
  }

  let runner = @riscv.make_runner(
    if virtio_blk_disk_bytes is Some(_) {
      @riscv.virtio_blk_machine_config()
    } else {
      @riscv.virt_machine_config()
    },
  )
  runner.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  runner.write_memory_bytes(kernel_entry_addr, kernel_bytes)
  runner.load_dtb(dtb_bytes)
  runner.write_memory_bytes(initrd_addr, initrd_bytes)
  match virtio_blk_disk_bytes {
    Some(bytes) => runner.load_virtio_blk_disk(bytes)
    None => ()
  }
  runner.setup_fw_dynamic_handoff(
    fw_dynamic_info_addr,
    kernel_entry_addr,
    1U.to_uint64(),
  )

  let mut steps = 0
  let mut output = ""
  let mut outcome = "timeout"
  let mut trapped = false
  let mut last_output_steps = 0
  let mut shell_command_sent = false
  let mut shell_expect_seen = false
  while steps < max_steps {
    match runner.step() {
      Running => {
        steps = steps + 1
        if steps % drain_interval == 0 {
          let partial = runner.uart_drain()
          if partial.length() > 0 {
            output = output + partial
            last_output_steps = steps
            if output.contains(alpine_shell_prompt_marker) {
              outcome = "alpine-shell-prompt"
              match command {
                Some(text) =>
                  if !shell_command_sent {
                    // Feed the command through the same UART input path that
                    // the browser host uses. This keeps the console probe
                    // grounded in guest-visible serial input instead of
                    // treating prompt reachability as the whole Linux proof.
                    runner.uart_push_input(text + "\r\n")
                    shell_command_sent = true
                  }
                None => break
              }
            } else if output.contains(alpine_shell_marker) {
              outcome = "alpine-shell"
            } else if output.contains(alpine_marker) {
              outcome = "alpine-marker"
            }
            match expect {
              Some(marker) =>
                if shell_command_sent && output.contains(marker) {
                  shell_expect_seen = true
                  outcome = "console-command"
                  break
                }
              None => if outcome == "alpine-shell-prompt" { break }
            }
          }
        }
      }
      Trap(info) => {
        trapped = true
        outcome = "trap pc=" +
          info.faulting_pc.to_string() +
          " tval=" +
          info.trap_value.to_string()
        break
      }
    }
  }
  let tail = runner.uart_drain()
  if tail.length() > 0 {
    output = output + tail
  }
  if outcome == "timeout" && output.contains(alpine_marker) {
    outcome = "alpine-marker"
  }
  if output.contains(alpine_shell_marker) {
    outcome = "alpine-shell"
  }
  if output.contains(alpine_shell_prompt_marker) {
    outcome = "alpine-shell-prompt"
  }
  match expect {
    Some(marker) =>
      if shell_command_sent && output.contains(marker) {
        shell_expect_seen = true
        outcome = "console-command"
      }
    None => ()
  }
  println("Alpine native probe")
  println("outcome=" + outcome)
  println("steps=" + steps.to_string())
  println("last_output_steps=" + last_output_steps.to_string())
  println("trapped=" + trapped.to_string())
  println("shell_command_sent=" + shell_command_sent.to_string())
  println("shell_expect_seen=" + shell_expect_seen.to_string())
  println("functional_smoke=" + functional_smoke.to_string())
  println("rootfs_smoke=" + rootfs_smoke.to_string())
  println("switch_root_smoke=" + switch_root_smoke.to_string())
  println("dtb_path=" + selected_dtb_path)
  println("initrd_path=" + selected_initrd_path)
  println("virtio_blk_disk=" + selected_virtio_blk_disk_path)
  println("final_pc=" + hex(runner.pc_u64()))
  println("final_privilege=" + privilege_name(runner.privilege_mode()))
  println("csr_sstatus=" + hex(runner.read_csr_u64(csr_sstatus)))
  println("csr_sie=" + hex(runner.read_csr_u64(csr_sie)))
  println("csr_sip=" + hex(runner.read_csr_u64(csr_sip)))
  println("csr_sepc=" + hex(runner.read_csr_u64(csr_sepc)))
  println("csr_scause=" + hex(runner.read_csr_u64(csr_scause)))
  println("csr_stval=" + hex(runner.read_csr_u64(csr_stval)))
  println("csr_satp=" + hex(runner.read_csr_u64(csr_satp)))
  println(
    "decode_cache=\{runner.decode_cache_hit_count()} hits/\{runner.decode_cache_miss_count()} misses",
  )
  println(
    "translate_cache=\{runner.translate_cache_hit_count()} hits/\{runner.translate_cache_miss_count()} misses",
  )
  println("output_chars=" + output.length().to_string())
  println(
    "contains_linux_version=" + output.contains("Linux version").to_string(),
  )
  println(
    "contains_initramfs_unpack=" +
    (output.contains(initramfs_unpack_marker_old) ||
    output.contains(initramfs_unpack_marker_new)).to_string(),
  )
  println(
    "contains_free_initmem=" + output.contains(free_initmem_marker).to_string(),
  )
  println(
    "contains_free_initrd=" + output.contains(free_initrd_marker).to_string(),
  )
  println("contains_run_init=" + output.contains(run_init_marker).to_string())
  println("contains_rootfs=" + output.contains(rootfs_marker).to_string())
  println("contains_virtio_blk=" + output.contains("virtio_blk").to_string())
  println("contains_vda=" + output.contains("vda").to_string())
  println(
    "contains_alpine_marker=" + output.contains(alpine_marker).to_string(),
  )
  println(
    "contains_alpine_shell=" + output.contains(alpine_shell_marker).to_string(),
  )
  println(
    "contains_alpine_shell_prompt=" +
    output.contains(alpine_shell_prompt_marker).to_string(),
  )
  let tail_start = if output.length() > 5000 {
    output.length() - 5000
  } else {
    0
  }
  println("tail:")
  println(output[tail_start:].to_owned())
}
