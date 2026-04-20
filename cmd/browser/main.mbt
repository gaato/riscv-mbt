///|
#cfg(target="js")
extern "js" fn dom_set_text(id : String, text : String) -> Unit =
  #| function(id, text) {
  #|   const node = document.getElementById(id);
  #|   if (!node) return;
  #|   node.textContent = text;
  #| }

///|
#cfg(target="js")
extern "js" fn dom_bind_click(id : String, callback : () -> Unit) -> Unit =
  #| function(id, callback) {
  #|   const node = document.getElementById(id);
  #|   if (!node) return;
  #|   node.addEventListener("click", () => callback());
  #| }

///|
#cfg(target="js")
extern "js" fn dom_bind_input_submit(
  input_id : String,
  button_id : String,
  callback : (String) -> Unit,
) -> Unit =
  #| function(inputId, buttonId, callback) {
  #|   const input = document.getElementById(inputId);
  #|   const button = document.getElementById(buttonId);
  #|   if (!input || !button) return;
  #|   const submit = () => {
  #|     const value = input.value;
  #|     input.value = "";
  #|     callback(value);
  #|   };
  #|   button.addEventListener("click", submit);
  #|   input.addEventListener("keydown", (event) => {
  #|     if (event.key === "Enter") {
  #|       event.preventDefault();
  #|       submit();
  #|     }
  #|   });
  #| }

///|
#cfg(target="js")
extern "js" fn dom_focus(id : String) -> Unit =
  #| function(id) {
  #|   const node = document.getElementById(id);
  #|   if (node && typeof node.focus === "function") {
  #|     node.focus();
  #|   }
  #| }

///|
#cfg(target="js")
extern "js" fn dom_set_interval(ms : Int, callback : () -> Unit) -> Unit =
  #| function(ms, callback) {
  #|   setInterval(() => callback(), ms);
  #| }

///|
fn encode_i(
  imm : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
  opcode : UInt,
) -> UInt {
  ((imm & 0xfff).reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
fn encode_s(
  imm : Int,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  opcode : UInt,
) -> UInt {
  let encoded = (imm & 0xfff).reinterpret_as_uint()
  (((encoded >> 5) & 0x7fU) << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  ((encoded & 0x1fU) << 7) |
  opcode
}

///|
fn encode_b(
  imm : Int,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  opcode : UInt,
) -> UInt {
  let encoded = (imm & 0x1fff).reinterpret_as_uint()
  (((encoded >> 12) & 0x1U) << 31) |
  (((encoded >> 5) & 0x3fU) << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (((encoded >> 1) & 0xfU) << 8) |
  (((encoded >> 11) & 0x1U) << 7) |
  opcode
}

///|
fn encode_u(imm : UInt, rd : Int, opcode : UInt) -> UInt {
  (imm & 0xfffff000U) | (rd.reinterpret_as_uint() << 7) | opcode
}

///|
fn encode_j(imm : Int, rd : Int, opcode : UInt) -> UInt {
  let encoded = (imm & 0x1fffff).reinterpret_as_uint()
  (((encoded >> 20) & 0x1U) << 31) |
  (((encoded >> 1) & 0x3ffU) << 21) |
  (((encoded >> 11) & 0x1U) << 20) |
  (((encoded >> 12) & 0xffU) << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
fn browser_demo_program_words() -> Array[UInt] {
  let words = [encode_u(0x10000000U, 1, 0x37U)]
  for ch in "echo ready\r\n> " {
    words.push(encode_i(ch.to_int(), 0, 0x0U, 2, 0x13U))
    words.push(encode_s(0, 2, 1, 0x0U, 0x23U))
  }
  words.push(encode_i(5, 1, 0x4U, 2, 0x03U))
  words.push(encode_i(1, 2, 0x7U, 2, 0x13U))
  words.push(encode_b(-8, 0, 2, 0x0U, 0x63U))
  words.push(encode_i(0, 1, 0x4U, 3, 0x03U))
  words.push(encode_s(0, 3, 1, 0x0U, 0x23U))
  words.push(encode_j(-20, 0, 0x6fU))
  words
}

///|
fn make_browser_demo_runner() -> @riscv.Runner {
  let config = @riscv.virt_machine_config()
  let runner = @riscv.make_runner(config)
  runner.load_program_u64(
    @riscv.words_to_bytes(browser_demo_program_words()),
    config.entry_point,
  )
  ignore(runner.run(256))
  runner
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
fn trap_cause_name(cause : @riscv.TrapCause) -> String {
  match cause {
    InstructionAccessFault => "instruction access fault"
    IllegalInstruction => "illegal instruction"
    LoadAccessFault => "load access fault"
    StoreAccessFault => "store access fault"
    InstructionPageFault => "instruction page fault"
    LoadPageFault => "load page fault"
    StorePageFault => "store page fault"
    EnvironmentCallFromUMode => "ecall from user mode"
    EnvironmentCallFromSMode => "ecall from supervisor mode"
    EnvironmentCallFromMMode => "ecall from machine mode"
    SupervisorSoftwareInterrupt => "supervisor software interrupt"
    MachineSoftwareInterrupt => "machine software interrupt"
    SupervisorTimerInterrupt => "supervisor timer interrupt"
    MachineTimerInterrupt => "machine timer interrupt"
    SupervisorExternalInterrupt => "supervisor external interrupt"
    MachineExternalInterrupt => "machine external interrupt"
  }
}

///|
fn runner_status_text(runner : @riscv.Runner, running : Bool) -> String {
  let mode = if running { "running" } else { "paused" }
  "mode: \{mode}\n" +
  "pc: 0x\{runner.pc_u64().to_string(radix=16)}\n" +
  "privilege: \{privilege_name(runner.privilege_mode())}\n" +
  "x1: 0x\{runner.read_reg_u64(1).to_string(radix=16)}\n" +
  "x2: 0x\{runner.read_reg_u64(2).to_string(radix=16)}\n" +
  "x3: 0x\{runner.read_reg_u64(3).to_string(radix=16)}\n" +
  "x4: 0x\{runner.read_reg_u64(4).to_string(radix=16)}"
}

///|
fn main {
  let mut runner = make_browser_demo_runner()
  let mut console_text = runner.uart_drain()
  let mut running = false

  let sync_ui = fn() {
    dom_set_text("console", console_text)
    dom_set_text("status", runner_status_text(runner, running))
    dom_set_text("run-toggle", if running { "Pause" } else { "Run" })
  }

  let pull_uart = fn() {
    let chunk = runner.uart_drain()
    if chunk != "" {
      console_text = console_text + chunk
    }
  }

  let handle_result = fn(result : @riscv.StepResult) {
    pull_uart()
    match result {
      Running => ()
      Trap(info) => {
        running = false
        console_text = console_text +
          "\n[trap] \{trap_cause_name(info.cause)} @ pc=0x\{info.faulting_pc.to_string(radix=16)} value=0x\{info.trap_value.to_string(radix=16)}\n"
      }
    }
    sync_ui()
  }

  let drive_guest = fn(step_budget : Int) {
    handle_result(runner.run(step_budget))
  }

  let reset_demo = fn() {
    running = false
    runner = make_browser_demo_runner()
    console_text = runner.uart_drain()
    sync_ui()
  }

  dom_set_text(
    "host-notes",
    "Shared core host. Input is pushed into the emulated UART RX queue and echoed by the guest.",
  )
  dom_bind_click("step", fn() {
    if !running {
      handle_result(runner.step())
    }
  })
  dom_bind_click("run-toggle", fn() {
    running = !running
    sync_ui()
  })
  dom_bind_click("reset", reset_demo)
  dom_bind_input_submit("serial-input", "send-input", fn(text) {
    if text != "" {
      runner.uart_push_input(text)
      runner.uart_push_input("\r\n")
      if !running {
        drive_guest(4096)
      } else {
        sync_ui()
      }
    }
  })
  dom_set_interval(16, fn() {
    if running {
      drive_guest(4096)
    }
  })
  sync_ui()
  dom_focus("serial-input")
}
