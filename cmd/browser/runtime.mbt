// Browser-facing runtime state and byte-oriented exports. Keep this boundary
// stable for JavaScript: artifacts, UART bytes, and status counters cross here.

///|
let browser_run_tick_budget : Int = 4096

///|
let browser_artifact_opensbi : Int = 1

///|
let browser_artifact_dtb : Int = 2

///|
let browser_artifact_kernel : Int = 3

///|
let browser_artifact_initrd : Int = 4

///|
let browser_linux_initrd_addr : UInt64 = 0x84000000U.to_uint64()

///|
let browser_guest_smoke : Int = 0

///|
let browser_guest_linux : Int = 1

///|
priv struct BrowserRuntime {
  // Browser state is deliberately byte-oriented. JS can stream artifact bytes
  // and UART bytes without understanding MoonBit object layouts or emulator RAM.
  mut runner : @riscv.Runner
  console_codes : Array[Int]
  mut running : Bool
  mut guest_kind : Int
  mut total_steps : UInt64
  mut pending_artifact_kind : Int
  mut pending_artifact_bytes : Array[Byte]
  mut has_opensbi : Bool
  mut opensbi_bytes : Array[Byte]
  mut has_dtb : Bool
  mut dtb_bytes : Array[Byte]
  mut has_kernel : Bool
  mut kernel_bytes : Array[Byte]
  mut has_initrd : Bool
  mut initrd_bytes : Array[Byte]
}

///|
fn BrowserRuntime::new_smoke() -> BrowserRuntime {
  let runner = make_browser_demo_runner()
  let runtime = {
    runner,
    console_codes: [],
    running: false,
    guest_kind: browser_guest_smoke,
    total_steps: 0U.to_uint64(),
    pending_artifact_kind: 0,
    pending_artifact_bytes: [],
    has_opensbi: false,
    opensbi_bytes: [],
    has_dtb: false,
    dtb_bytes: [],
    has_kernel: false,
    kernel_bytes: [],
    has_initrd: false,
    initrd_bytes: [],
  }
  runtime.drain_uart()
  runtime
}

///|
fn BrowserRuntime::drain_uart(self : BrowserRuntime) -> Unit {
  let len = self.runner.uart_output_length()
  let mut index = 0
  while index < len {
    self.console_codes.push(self.runner.uart_output_byte_at(index))
    index = index + 1
  }
  self.runner.uart_clear_output()
}

///|
fn BrowserRuntime::append_text(self : BrowserRuntime, text : String) -> Unit {
  for ch in text {
    self.console_codes.push(ch.to_int())
  }
}

///|
fn BrowserRuntime::handle_result(
  self : BrowserRuntime,
  result : @riscv.StepResult,
) -> Unit {
  self.drain_uart()
  match result {
    Running => ()
    Trap(_) => {
      self.running = false
      self.append_text("\n[trap]\n")
    }
  }
}

///|
fn BrowserRuntime::step_when_paused(self : BrowserRuntime) -> Unit {
  if !self.running {
    self.handle_result(self.runner.step())
    self.total_steps = self.total_steps + 1U.to_uint64()
  }
}

///|
fn BrowserRuntime::run_tick(self : BrowserRuntime) -> Unit {
  self.run_for(browser_run_tick_budget)
}

///|
fn BrowserRuntime::run_for(self : BrowserRuntime, step_budget : Int) -> Unit {
  if self.running {
    // The browser host controls wall-clock pacing; the core only receives a
    // bounded guest-step budget so long Linux runs can yield to the UI.
    self.handle_result(self.runner.run(step_budget))
    self.total_steps = self.total_steps +
      step_budget.reinterpret_as_uint().to_uint64()
  }
}

///|
fn BrowserRuntime::toggle_run(self : BrowserRuntime) -> Unit {
  self.running = !self.running
}

///|
fn BrowserRuntime::begin_artifact(self : BrowserRuntime, kind : Int) -> Unit {
  self.pending_artifact_kind = kind
  self.pending_artifact_bytes = []
}

///|
fn BrowserRuntime::push_artifact_byte(
  self : BrowserRuntime,
  value : Int,
) -> Unit {
  self.pending_artifact_bytes.push((value & 0xff).to_byte())
}

///|
fn BrowserRuntime::push_artifact_word(
  self : BrowserRuntime,
  value : Int,
  count : Int,
) -> Unit {
  if count > 0 {
    self.pending_artifact_bytes.push((value & 0xff).to_byte())
  }
  if count > 1 {
    self.pending_artifact_bytes.push(((value >> 8) & 0xff).to_byte())
  }
  if count > 2 {
    self.pending_artifact_bytes.push(((value >> 16) & 0xff).to_byte())
  }
  if count > 3 {
    self.pending_artifact_bytes.push(((value >> 24) & 0xff).to_byte())
  }
}

///|
fn BrowserRuntime::push_artifact_words4(
  self : BrowserRuntime,
  word0 : Int,
  word1 : Int,
  word2 : Int,
  word3 : Int,
  count : Int,
) -> Unit {
  self.push_artifact_word(word0, count)
  self.push_artifact_word(word1, count - 4)
  self.push_artifact_word(word2, count - 8)
  self.push_artifact_word(word3, count - 12)
}

///|
fn BrowserRuntime::finish_artifact(self : BrowserRuntime) -> Bool {
  match self.pending_artifact_kind {
    _ if self.pending_artifact_kind == browser_artifact_opensbi => {
      self.opensbi_bytes = self.pending_artifact_bytes
      self.has_opensbi = true
    }
    _ if self.pending_artifact_kind == browser_artifact_dtb => {
      self.dtb_bytes = self.pending_artifact_bytes
      self.has_dtb = true
    }
    _ if self.pending_artifact_kind == browser_artifact_kernel => {
      self.kernel_bytes = self.pending_artifact_bytes
      self.has_kernel = true
    }
    _ if self.pending_artifact_kind == browser_artifact_initrd => {
      self.initrd_bytes = self.pending_artifact_bytes
      self.has_initrd = true
    }
    _ => ()
  }
  self.pending_artifact_kind = 0
  self.pending_artifact_bytes = []
  self.linux_artifacts_ready()
}

///|
fn BrowserRuntime::linux_artifacts_ready(self : BrowserRuntime) -> Bool {
  self.has_opensbi && self.has_dtb && self.has_kernel
}

///|
fn BrowserRuntime::load_linux_from_artifacts(self : BrowserRuntime) -> Unit {
  if !self.linux_artifacts_ready() {
    self.append_text("\n[linux artifacts incomplete]\n")
    return
  }
  let runner = @riscv.make_runner(@riscv.virt_machine_config())
  runner.load_program_u64(
    Bytes::from_array(self.opensbi_bytes),
    0x80000000U.to_uint64(),
  )
  runner.write_memory_bytes(
    0x80200000U.to_uint64(),
    Bytes::from_array(self.kernel_bytes),
  )
  runner.load_dtb(Bytes::from_array(self.dtb_bytes))
  if self.has_initrd {
    runner.write_memory_bytes(
      browser_linux_initrd_addr,
      Bytes::from_array(self.initrd_bytes),
    )
  }
  runner.setup_fw_dynamic_handoff(
    0x80100000U.to_uint64(),
    0x80200000U.to_uint64(),
    1U.to_uint64(),
  )
  self.runner = runner
  self.console_codes.clear()
  self.running = false
  self.guest_kind = browser_guest_linux
  self.total_steps = 0U.to_uint64()
  self.drain_uart()
}

///|
fn BrowserRuntime::try_load_linux_from_artifacts(self : BrowserRuntime) -> Bool {
  if self.linux_artifacts_ready() {
    self.load_linux_from_artifacts()
    true
  } else {
    false
  }
}

///|
fn BrowserRuntime::artifact_loaded_mask(self : BrowserRuntime) -> Int {
  let mut mask = 0
  if self.has_opensbi {
    mask = mask | 1
  }
  if self.has_dtb {
    mask = mask | 2
  }
  if self.has_kernel {
    mask = mask | 4
  }
  if self.has_initrd {
    mask = mask | 8
  }
  mask
}

///|
fn BrowserRuntime::guest(self : BrowserRuntime) -> Int {
  self.guest_kind
}

///|
fn BrowserRuntime::artifact_size(self : BrowserRuntime, kind : Int) -> Int {
  match kind {
    _ if kind == browser_artifact_opensbi => self.opensbi_bytes.length()
    _ if kind == browser_artifact_dtb => self.dtb_bytes.length()
    _ if kind == browser_artifact_kernel => self.kernel_bytes.length()
    _ if kind == browser_artifact_initrd => self.initrd_bytes.length()
    _ => 0
  }
}

///|
fn BrowserRuntime::steps(self : BrowserRuntime) -> UInt64 {
  self.total_steps
}

///|
fn BrowserRuntime::decode_cache_hits(self : BrowserRuntime) -> UInt64 {
  self.runner.decode_cache_hit_count()
}

///|
fn BrowserRuntime::decode_cache_misses(self : BrowserRuntime) -> UInt64 {
  self.runner.decode_cache_miss_count()
}

///|
fn BrowserRuntime::translate_cache_hits(self : BrowserRuntime) -> UInt64 {
  self.runner.translate_cache_hit_count()
}

///|
fn BrowserRuntime::translate_cache_misses(self : BrowserRuntime) -> UInt64 {
  self.runner.translate_cache_miss_count()
}

///|
fn BrowserRuntime::send_input(self : BrowserRuntime, text : String) -> Unit {
  if text != "" {
    self.runner.uart_push_input(text)
    self.runner.uart_push_input("\r\n")
    if !self.running {
      self.handle_result(self.runner.run(browser_run_tick_budget))
      self.total_steps = self.total_steps +
        browser_run_tick_budget.reinterpret_as_uint().to_uint64()
    }
  }
}

///|
fn BrowserRuntime::send_input_byte(self : BrowserRuntime, value : Int) -> Unit {
  self.runner.uart_push_input_byte(value)
}

///|
fn BrowserRuntime::flush_input_when_paused(self : BrowserRuntime) -> Unit {
  if !self.running {
    self.handle_result(self.runner.run(browser_run_tick_budget))
    self.total_steps = self.total_steps +
      browser_run_tick_budget.reinterpret_as_uint().to_uint64()
  }
}

///|
fn BrowserRuntime::console_length(self : BrowserRuntime) -> Int {
  self.console_codes.length()
}

///|
fn BrowserRuntime::console_code_at(self : BrowserRuntime, index : Int) -> Int {
  self.console_codes[index]
}

///|
fn BrowserRuntime::pc(self : BrowserRuntime) -> UInt64 {
  self.runner.pc_u64()
}

///|
fn BrowserRuntime::privilege(self : BrowserRuntime) -> Int {
  match self.runner.privilege_mode() {
    User => 0
    Supervisor => 1
    Machine => 3
  }
}

///|
fn BrowserRuntime::reg(self : BrowserRuntime, index : Int) -> UInt64 {
  self.runner.read_reg_u64(index)
}

///|
fn BrowserRuntime::is_running(self : BrowserRuntime) -> Bool {
  self.running
}
