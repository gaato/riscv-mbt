// ---------------------------------------------------------------------------
// Physical address dispatch layer
// Bus handles RAM; this layer adds MMIO devices (UART, CLINT).
// A device is disabled when its base address in MachineConfig is zero.
// ---------------------------------------------------------------------------

///|
pub(all) enum PhyTarget {
  PhyRam
  PhyUart(UInt64) // offset within UART register bank
  PhyClint(UInt64) // offset within CLINT region
  PhyPlic(UInt64) // offset within PLIC region
  PhyNone // unmapped
}

///|
fn Runner::phy_dispatch(self : Runner, pa : UInt64, width : Int) -> PhyTarget {
  if self.bus.contains_range(pa, width) {
    return PhyRam
  }
  let w = width.to_uint64()
  let zero = 0U.to_uint64()
  if self.config.uart0_base != zero {
    let base = self.config.uart0_base
    let end = base + 8U.to_uint64()
    if pa >= base && pa + w <= end {
      return PhyUart(pa - base)
    }
  }
  if self.config.clint_base != zero {
    let base = self.config.clint_base
    let end = base + 0x10000U.to_uint64()
    if pa >= base && pa + w <= end {
      return PhyClint(pa - base)
    }
  }
  if self.config.plic_base != zero {
    let base = self.config.plic_base
    let end = base + 0x400000U.to_uint64()
    if pa >= base && pa + w <= end {
      return PhyPlic(pa - base)
    }
  }
  PhyNone
}

///|
fn Runner::phy_contains(self : Runner, pa : UInt64, width : Int) -> Bool {
  match self.phy_dispatch(pa, width) {
    PhyNone => false
    _ => true
  }
}

///|
// CLINT offsets (from QEMU virt / SiFive CLINT spec)
let clint_mtime_lo_offset : UInt64 = 0xBFF8U.to_uint64()

let clint_mtime_hi_offset : UInt64 = 0xBFFCU.to_uint64()

let clint_mtimecmp_lo_offset : UInt64 = 0x4000U.to_uint64()

let clint_mtimecmp_hi_offset : UInt64 = 0x4004U.to_uint64()

// ---------------------------------------------------------------------------
// UART register read/write (16550A minimum)
// ---------------------------------------------------------------------------

///|
fn Runner::uart_read(self : Runner, off : UInt64) -> UInt64 {
  // LSR (offset 5): always report THRE+TEMT (TX empty)
  if off == 5U.to_uint64() {
    return 0x60U.to_uint64()
  }
  0U.to_uint64()
}

///|
fn Runner::uart_write(self : Runner, off : UInt64, value : UInt64) -> Unit {
  // THR (offset 0): capture the character
  if off == 0U.to_uint64() {
    self.uart_output.push(value.to_byte())
  }
}

// ---------------------------------------------------------------------------
// PLIC register read/write (flat register file, claim always returns 0)
// Layout: priority 0x000000, pending 0x001000, enable 0x002000,
//         threshold 0x200000+ctx*0x1000, claim 0x200004+ctx*0x1000
// ---------------------------------------------------------------------------

///|
fn Runner::plic_read_u8(self : Runner, off : UInt64) -> UInt64 {
  let idx = off.to_int()
  if idx < self.plic_regs.length() {
    self.plic_regs[idx].to_uint64()
  } else {
    0U.to_uint64()
  }
}

///|
fn Runner::plic_read_u32(self : Runner, off : UInt64) -> UInt64 {
  let idx = off.to_int()
  // Claim register: offset 0x200004 + context*0x1000, always returns 0
  let ctx_off = idx - 0x200000
  if ctx_off >= 0 && ctx_off % 0x1000 == 4 {
    return 0U.to_uint64()
  }
  if idx + 3 < self.plic_regs.length() {
    self.plic_regs[idx].to_uint64() |
    (self.plic_regs[idx + 1].to_uint64() << 8) |
    (self.plic_regs[idx + 2].to_uint64() << 16) |
    (self.plic_regs[idx + 3].to_uint64() << 24)
  } else {
    0U.to_uint64()
  }
}

///|
fn Runner::plic_write_u8(self : Runner, off : UInt64, value : UInt64) -> Unit {
  let idx = off.to_int()
  if idx < self.plic_regs.length() {
    self.plic_regs[idx] = value.to_byte()
  }
}

///|
fn Runner::plic_write_u32(
  self : Runner,
  off : UInt64,
  value : UInt64,
) -> Unit {
  let idx = off.to_int()
  // Complete register: same offset as claim (0x200004+ctx*0x1000), write ignored
  let ctx_off = idx - 0x200000
  if ctx_off >= 0 && ctx_off % 0x1000 == 4 {
    return
  }
  if idx + 3 < self.plic_regs.length() {
    self.plic_regs[idx] = value.to_byte()
    self.plic_regs[idx + 1] = (value >> 8).to_byte()
    self.plic_regs[idx + 2] = (value >> 16).to_byte()
    self.plic_regs[idx + 3] = (value >> 24).to_byte()
  }
}

// ---------------------------------------------------------------------------
// Physical load helpers — dispatch on PhyTarget
// ---------------------------------------------------------------------------

///|
fn Runner::phy_load_u8(self : Runner, pa : UInt64) -> UInt64 {
  match self.phy_dispatch(pa, 1) {
    PhyUart(off) => self.uart_read(off)
    PhyClint(off) => self.clint_reg_byte(off)
    PhyPlic(off) => self.plic_read_u8(off)
    _ => self.bus.load_u8(pa)
  }
}

///|
fn Runner::phy_load_u16(self : Runner, pa : UInt64) -> UInt64 {
  match self.phy_dispatch(pa, 2) {
    PhyUart(_) => 0U.to_uint64()
    PhyClint(off) => self.clint_reg_halfword(off)
    PhyPlic(off) =>
      self.plic_read_u8(off) | (self.plic_read_u8(off + 1U.to_uint64()) << 8)
    _ => self.bus.load_u16(pa)
  }
}

///|
fn Runner::phy_load_u32(self : Runner, pa : UInt64) -> UInt64 {
  match self.phy_dispatch(pa, 4) {
    PhyUart(_) => 0U.to_uint64()
    PhyClint(off) => self.clint_reg_word(off)
    PhyPlic(off) => self.plic_read_u32(off)
    _ => self.bus.load_u32(pa)
  }
}

///|
fn Runner::phy_load_u64(self : Runner, pa : UInt64) -> UInt64 {
  match self.phy_dispatch(pa, 8) {
    PhyUart(_) => 0U.to_uint64()
    PhyClint(off) => self.clint_reg_dword(off)
    PhyPlic(off) =>
      self.plic_read_u32(off) |
      (self.plic_read_u32(off + 4U.to_uint64()) << 32)
    _ => self.bus.load_u64(pa)
  }
}

// ---------------------------------------------------------------------------
// Physical store helpers — dispatch on PhyTarget
// ---------------------------------------------------------------------------

///|
fn Runner::phy_store_u8(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  match self.phy_dispatch(pa, 1) {
    PhyUart(off) => self.uart_write(off, value)
    PhyClint(off) => self.clint_store_byte(off, value)
    PhyPlic(off) => self.plic_write_u8(off, value)
    _ => self.bus.store_u8(pa, value)
  }
}

///|
fn Runner::phy_store_u16(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  match self.phy_dispatch(pa, 2) {
    PhyUart(_) => ()
    PhyClint(off) => self.clint_store_halfword(off, value)
    PhyPlic(off) => {
      self.plic_write_u8(off, value)
      self.plic_write_u8(off + 1U.to_uint64(), value >> 8)
    }
    _ => self.bus.store_u16(pa, value)
  }
}

///|
fn Runner::phy_store_u32(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  match self.phy_dispatch(pa, 4) {
    PhyUart(_) => ()
    PhyClint(off) => self.clint_store_word(off, value)
    PhyPlic(off) => self.plic_write_u32(off, value)
    _ => self.bus.store_u32(pa, value)
  }
}

///|
fn Runner::phy_store_u64(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  match self.phy_dispatch(pa, 8) {
    PhyUart(_) => ()
    PhyClint(off) => self.clint_store_dword(off, value)
    PhyPlic(off) => {
      self.plic_write_u32(off, value)
      self.plic_write_u32(off + 4U.to_uint64(), value >> 32)
    }
    _ => self.bus.store_u64(pa, value)
  }
}

// ---------------------------------------------------------------------------
// CLINT register helpers (little-endian byte-addressed MMIO)
// Only mtime and mtimecmp[0] are implemented.
// ---------------------------------------------------------------------------

///|
fn Runner::clint_reg_byte(self : Runner, off : UInt64) -> UInt64 {
  if off >= clint_mtime_lo_offset && off < clint_mtime_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtime_lo_offset).to_int() * 8
    return (self.mtime >> shift) & 0xffU.to_uint64()
  }
  if off >= clint_mtimecmp_lo_offset &&
    off < clint_mtimecmp_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtimecmp_lo_offset).to_int() * 8
    return (self.mtimecmp >> shift) & 0xffU.to_uint64()
  }
  0U.to_uint64()
}

///|
fn Runner::clint_reg_halfword(self : Runner, off : UInt64) -> UInt64 {
  if off >= clint_mtime_lo_offset && off + 2U.to_uint64() <= clint_mtime_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtime_lo_offset).to_int() * 8
    return (self.mtime >> shift) & 0xffffU.to_uint64()
  }
  if off >= clint_mtimecmp_lo_offset &&
    off + 2U.to_uint64() <= clint_mtimecmp_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtimecmp_lo_offset).to_int() * 8
    return (self.mtimecmp >> shift) & 0xffffU.to_uint64()
  }
  0U.to_uint64()
}

///|
fn Runner::clint_reg_word(self : Runner, off : UInt64) -> UInt64 {
  if off == clint_mtime_lo_offset {
    return self.mtime & 0xffffffffU.to_uint64()
  }
  if off == clint_mtime_hi_offset {
    return self.mtime >> 32
  }
  if off == clint_mtimecmp_lo_offset {
    return self.mtimecmp & 0xffffffffU.to_uint64()
  }
  if off == clint_mtimecmp_hi_offset {
    return self.mtimecmp >> 32
  }
  0U.to_uint64()
}

///|
fn Runner::clint_reg_dword(self : Runner, off : UInt64) -> UInt64 {
  if off == clint_mtime_lo_offset {
    return self.mtime
  }
  if off == clint_mtimecmp_lo_offset {
    return self.mtimecmp
  }
  0U.to_uint64()
}

///|
fn Runner::clint_store_byte(self : Runner, off : UInt64, value : UInt64) -> Unit {
  let byte_val = value & 0xffU.to_uint64()
  if off >= clint_mtime_lo_offset && off < clint_mtime_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtime_lo_offset).to_int() * 8
    let mask = bit_not(0xffU.to_uint64() << shift)
    self.mtime = (self.mtime & mask) | (byte_val << shift)
    return
  }
  if off >= clint_mtimecmp_lo_offset &&
    off < clint_mtimecmp_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtimecmp_lo_offset).to_int() * 8
    let mask = bit_not(0xffU.to_uint64() << shift)
    self.mtimecmp = (self.mtimecmp & mask) | (byte_val << shift)
    return
  }
}

///|
fn Runner::clint_store_halfword(
  self : Runner,
  off : UInt64,
  value : UInt64,
) -> Unit {
  let hw_val = value & 0xffffU.to_uint64()
  if off >= clint_mtime_lo_offset &&
    off + 2U.to_uint64() <= clint_mtime_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtime_lo_offset).to_int() * 8
    let mask = bit_not(0xffffU.to_uint64() << shift)
    self.mtime = (self.mtime & mask) | (hw_val << shift)
    return
  }
  if off >= clint_mtimecmp_lo_offset &&
    off + 2U.to_uint64() <= clint_mtimecmp_lo_offset + 8U.to_uint64() {
    let shift = (off - clint_mtimecmp_lo_offset).to_int() * 8
    let mask = bit_not(0xffffU.to_uint64() << shift)
    self.mtimecmp = (self.mtimecmp & mask) | (hw_val << shift)
    return
  }
}

///|
fn Runner::clint_store_word(self : Runner, off : UInt64, value : UInt64) -> Unit {
  let w_val = value & 0xffffffffU.to_uint64()
  if off == clint_mtime_lo_offset {
    self.mtime = (self.mtime & bit_not(0xffffffffU.to_uint64())) | w_val
    return
  }
  if off == clint_mtime_hi_offset {
    self.mtime = (self.mtime & 0xffffffffU.to_uint64()) | (w_val << 32)
    return
  }
  if off == clint_mtimecmp_lo_offset {
    self.mtimecmp = (self.mtimecmp & bit_not(0xffffffffU.to_uint64())) | w_val
    return
  }
  if off == clint_mtimecmp_hi_offset {
    self.mtimecmp =
      (self.mtimecmp & 0xffffffffU.to_uint64()) | (w_val << 32)
    return
  }
}

///|
fn Runner::clint_store_dword(self : Runner, off : UInt64, value : UInt64) -> Unit {
  if off == clint_mtime_lo_offset {
    self.mtime = value
    return
  }
  if off == clint_mtimecmp_lo_offset {
    self.mtimecmp = value
  }
}

// ---------------------------------------------------------------------------
// Public accessors for testing and OpenSBI integration
// ---------------------------------------------------------------------------

///|
pub fn Runner::uart_drain(self : Runner) -> String {
  let bytes = self.uart_output.copy()
  self.uart_output.clear()
  String::from_array(bytes.map(fn(b) { b.to_int().unsafe_to_char() }))
}

///|
pub fn Runner::clint_mtime(self : Runner) -> UInt64 {
  self.mtime
}

///|
pub fn Runner::clint_mtimecmp(self : Runner) -> UInt64 {
  self.mtimecmp
}

// ---------------------------------------------------------------------------
// Timer tick: advance mtime and set/clear MIP.MTIP
// Called once per step() before instruction execution.
// ---------------------------------------------------------------------------

///|
let mip_mtip_bit : UInt64 = 0x80U.to_uint64() // bit 7

///|
fn Runner::update_timer(self : Runner) -> Unit {
  if self.config.clint_base == 0U.to_uint64() {
    return
  }
  self.mtime = self.mtime + 1U.to_uint64()
  let mip = self.cpu.read_csr(CSR_MIP)
  if self.mtime >= self.mtimecmp {
    self.cpu.write_csr(CSR_MIP, mip | mip_mtip_bit)
  } else {
    self.cpu.write_csr(CSR_MIP, mip & bit_not(mip_mtip_bit))
  }
}

///|
fn Runner::trap_target_for_privilege(
  self : Runner,
  target_privilege : PrivilegeMode,
  cause : TrapCause,
) -> UInt64 {
  let tvec_csr = match target_privilege {
    Supervisor => CSR_STVEC
    Machine => CSR_MTVEC
    User => return 0U.to_uint64()
  }
  let tvec = self.read_csr_visible(tvec_csr)
  let mode = tvec & 0x3U.to_uint64()
  let base = tvec & bit_not(0x3U.to_uint64())
  // Vectored mode (mode=1): PC = base + 4 * cause_code for interrupts
  if mode == 1U.to_uint64() && self.trap_cause_is_interrupt(cause) {
    let code = trap_cause_code(cause) & bit_not(1U.to_uint64() << 63)
    base + (code << 2)
  } else {
    base
  }
}

///|
fn Runner::enter_machine_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt64,
  trap_value : UInt64,
  prior_privilege : PrivilegeMode,
) -> Unit {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let next_mstatus = set_mstatus_mie(
    set_mstatus_mpie(
      set_mstatus_mpp(mstatus, prior_privilege),
      mstatus_mie(mstatus),
    ),
    false,
  )
  self.cpu.write_csr(CSR_MSTATUS, next_mstatus)
  self.cpu.write_csr(CSR_MEPC, faulting_pc)
  self.cpu.write_csr(CSR_MCAUSE, trap_cause_code(cause))
  self.cpu.write_csr(CSR_MTVAL, trap_value)
  self.cpu.privilege = Machine
}

///|
fn Runner::enter_supervisor_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt64,
  trap_value : UInt64,
  prior_privilege : PrivilegeMode,
) -> Unit {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let next_mstatus = set_mstatus_sie(
    set_mstatus_spie(
      set_mstatus_spp(mstatus, prior_privilege),
      mstatus_sie(mstatus),
    ),
    false,
  )
  self.cpu.write_csr(CSR_MSTATUS, next_mstatus)
  self.cpu.write_csr(CSR_SEPC, faulting_pc)
  self.cpu.write_csr(CSR_SCAUSE, trap_cause_code(cause))
  self.cpu.write_csr(CSR_STVAL, trap_value)
  self.cpu.privilege = Supervisor
}

///|
fn Runner::trap_target_privilege(
  self : Runner,
  cause : TrapCause,
  prior_privilege : PrivilegeMode,
) -> PrivilegeMode {
  if self.trap_cause_is_interrupt(cause) {
    self.delegated_interrupt_target(cause, prior_privilege)
  } else {
    self.delegated_exception_target(cause, prior_privilege)
  }
}

///|
fn Runner::trap_cause_is_interrupt(_self : Runner, cause : TrapCause) -> Bool {
  match cause {
    SupervisorSoftwareInterrupt | MachineSoftwareInterrupt |
    SupervisorTimerInterrupt | MachineTimerInterrupt |
    SupervisorExternalInterrupt | MachineExternalInterrupt => true
    _ => false
  }
}

///|
fn Runner::delegated_interrupt_target(
  self : Runner,
  cause : TrapCause,
  prior_privilege : PrivilegeMode,
) -> PrivilegeMode {
  let mideleg = self.cpu.read_csr(CSR_MIDELEG)
  let code = trap_cause_code(cause) & bit_not(1U.to_uint64() << 63)
  let bit = 1U.to_uint64() << code.to_int()
  // Cannot delegate to a privilege higher than or equal to the trapping privilege
  let may_delegate = match prior_privilege {
    Machine => false
    _ => true
  }
  if may_delegate && (mideleg & bit) != 0U.to_uint64() {
    Supervisor
  } else {
    Machine
  }
}

///|
fn Runner::delegated_exception_target(
  self : Runner,
  cause : TrapCause,
  prior_privilege : PrivilegeMode,
) -> PrivilegeMode {
  let may_delegate_to_supervisor = match prior_privilege {
    Machine => false
    _ => true
  }
  if !may_delegate_to_supervisor {
    return Machine
  }
  let cause_code = trap_cause_code(cause)
  let cause_shift = cause_code.reinterpret_as_int64().to_int()
  let medeleg = self.cpu.read_csr(CSR_MEDELEG)
  let delegated = (medeleg & (1U.to_uint64() << cause_shift)) != 0U.to_uint64()
  if delegated {
    Supervisor
  } else {
    Machine
  }
}

///|
fn Runner::raise_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt64,
  trap_value : UInt64,
) -> StepResult {
  let prior_privilege = self.cpu.privilege
  let target_privilege = self.trap_target_privilege(cause, prior_privilege)
  match target_privilege {
    Supervisor => self.enter_supervisor_trap(cause, faulting_pc, trap_value, prior_privilege)
    Machine => self.enter_machine_trap(cause, faulting_pc, trap_value, prior_privilege)
    User => self.enter_machine_trap(cause, faulting_pc, trap_value, prior_privilege)
  }
  let target = self.trap_target_for_privilege(target_privilege, cause)
  // Jump to trap handler regardless of whether the target is in physical RAM:
  // virtual trap vectors are valid when Sv39 is active (translation happens on next fetch).
  if target != 0U.to_uint64() {
    self.cpu.pc = target
    Running
  } else {
    Trap({ cause, faulting_pc, trap_value })
  }
}

///|
