let opensbi_path = "_build/opensbi-riscv64-fw_dynamic.bin"
let kernel_path = "_build/linux-kernel-riscv64"
let dtb_path = "_build/minimal-alpine.dtb"
let initrd_path = "_build/alpine-initramfs-riscv64.cpio"
let initrd_addr : UInt64 = 0x84000000U.to_uint64()
let fw_dynamic_info_addr : UInt64 = 0x80100000U.to_uint64()
let kernel_entry_addr : UInt64 = 0x80200000U.to_uint64()
let alpine_marker = "riscv-mbt Alpine initramfs ready"
let initramfs_unpack_marker_old = "Trying to unpack rootfs image as initramfs"
let initramfs_unpack_marker_new = "Unpacking initramfs..."
let default_max_steps = 300000000
let drain_interval = 1000000

///|
async fn read_binary(path : String) -> Bytes {
  try {
    @fs.read_file(path).binary()
  } catch {
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
      "xlong" => 1000000000
      _ => default_max_steps
    }
  } else {
    default_max_steps
  }
}

///|
async fn main {
  let args = @env.args()
  let max_steps = parse_max_steps(args)
  let fw_bytes = read_binary(opensbi_path)
  let kernel_bytes = read_binary(kernel_path)
  let dtb_bytes = read_binary(dtb_path)
  let initrd_bytes = read_binary(initrd_path)

  let runner = @riscv.make_runner(@riscv.virt_machine_config())
  runner.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  runner.write_memory_bytes(kernel_entry_addr, kernel_bytes)
  runner.load_dtb(dtb_bytes)
  runner.write_memory_bytes(initrd_addr, initrd_bytes)
  runner.setup_fw_dynamic_handoff(
    fw_dynamic_info_addr,
    kernel_entry_addr,
    1U.to_uint64(),
  )

  let mut steps = 0
  let mut output = ""
  let mut outcome = "timeout"
  let mut trapped = false
  while steps < max_steps {
    match runner.step() {
      Running => {
        steps = steps + 1
        if steps % drain_interval == 0 {
          let partial = runner.uart_drain()
          if partial.length() > 0 {
            output = output + partial
            if output.contains(alpine_marker) {
              outcome = "alpine-marker"
              break
            }
          }
        }
      }
      Trap(info) => {
        trapped = true
        outcome = "trap pc=" + info.faulting_pc.to_string() +
          " tval=" + info.trap_value.to_string()
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
  println("Alpine native probe")
  println("outcome=" + outcome)
  println("steps=" + steps.to_string())
  println("trapped=" + trapped.to_string())
  println(
    "decode_cache=\{runner.decode_cache_hit_count()} hits/\{runner.decode_cache_miss_count()} misses",
  )
  println(
    "translate_cache=\{runner.translate_cache_hit_count()} hits/\{runner.translate_cache_miss_count()} misses",
  )
  println("output_chars=" + output.length().to_string())
  println("contains_linux_version=" + output.contains("Linux version").to_string())
  println(
    "contains_initramfs_unpack=" +
    (
      output.contains(initramfs_unpack_marker_old) ||
      output.contains(initramfs_unpack_marker_new)
    ).to_string(),
  )
  println("contains_alpine_marker=" + output.contains(alpine_marker).to_string())
  let tail_start = if output.length() > 2000 { output.length() - 2000 } else { 0 }
  println("tail:")
  println(output[tail_start:].to_owned())
}
