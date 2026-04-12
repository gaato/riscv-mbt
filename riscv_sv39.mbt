///|
const PTE_V : UInt64 = 0x1
const PTE_R : UInt64 = 0x2
const PTE_W : UInt64 = 0x4
const PTE_X : UInt64 = 0x8
const PTE_U : UInt64 = 0x10
const PTE_A : UInt64 = 0x40
const PTE_D : UInt64 = 0x80
const SV39_LEVELS : Int = 3
const SV39_PAGESIZE : UInt64 = 4096
const SV39_PTESIZE : UInt64 = 8

///|
fn satp_ppn(satp : UInt64) -> UInt64 {
  satp & ((1U.to_uint64() << 44) - 1U.to_uint64())
}

///|
fn sv39_vpn(vaddr : UInt64, level : Int) -> UInt64 {
  (vaddr >> (12 + level * 9)) & 0x1FFU.to_uint64()
}

///|
fn sv39_va_canonical(vaddr : UInt64) -> Bool {
  let bit38 = (vaddr >> 38) & 1U.to_uint64()
  let upper = (vaddr >> 39) & 0x1FFFFFFU.to_uint64()
  if bit38 == 0U.to_uint64() {
    upper == 0U.to_uint64()
  } else {
    upper == 0x1FFFFFFU.to_uint64()
  }
}

///|
fn pte_ppn(pte : UInt64) -> UInt64 {
  (pte >> 10) & ((1U.to_uint64() << 44) - 1U.to_uint64())
}

///|
fn pte_ppn_i(pte : UInt64, level : Int) -> UInt64 {
  (pte >> (10 + level * 9)) & 0x1FFU.to_uint64()
}

///|
pub fn sv39_translate(
  bus : Bus,
  satp : UInt64,
  vaddr : UInt64,
  access_type : AccessType,
  privilege : PrivilegeMode,
  sum : Bool,
  mxr : Bool,
) -> TranslateResult {
  let fault = access_type_fault(access_type)
  if !sv39_va_canonical(vaddr) {
    return TranslateFault(fault)
  }
  let mut a = satp_ppn(satp) * SV39_PAGESIZE
  let mut i = SV39_LEVELS - 1
  // Page table walk loop
  let mut pte = 0U.to_uint64()
  while i >= 0 {
    let pte_addr = a + sv39_vpn(vaddr, i) * SV39_PTESIZE
    if !bus.contains_range(pte_addr, 8) {
      return TranslateFault(fault)
    }
    pte = bus.load_u64(pte_addr)
    // Invalid PTE: V=0 or (W=1 and R=0)
    if (pte & PTE_V) == 0U.to_uint64() ||
      ((pte & PTE_R) == 0U.to_uint64() && (pte & PTE_W) != 0U.to_uint64()) {
      return TranslateFault(fault)
    }
    // Leaf PTE: R=1 or X=1
    if (pte & PTE_R) != 0U.to_uint64() || (pte & PTE_X) != 0U.to_uint64() {
      break
    }
    // Non-leaf: descend
    a = pte_ppn(pte) * SV39_PAGESIZE
    i = i - 1
    if i < 0 {
      return TranslateFault(fault)
    }
  } nobreak {
    // Loop exhausted without finding a leaf
    return TranslateFault(fault)
  }
  // Leaf PTE found at level i
  // Permission checks
  match access_type {
    Fetch =>
      if (pte & PTE_X) == 0U.to_uint64() {
        return TranslateFault(fault)
      }
    Load =>
      if (pte & PTE_R) == 0U.to_uint64() &&
        !(mxr && (pte & PTE_X) != 0U.to_uint64()) {
        return TranslateFault(fault)
      }
    Store =>
      if (pte & PTE_W) == 0U.to_uint64() {
        return TranslateFault(fault)
      }
  }
  // U-bit check
  let is_user_page = (pte & PTE_U) != 0U.to_uint64()
  match privilege {
    User =>
      if !is_user_page {
        return TranslateFault(fault)
      }
    Supervisor =>
      if is_user_page && !sum {
        return TranslateFault(fault)
      }
    Machine => ()
  }
  // Superpage alignment: for level > 0, lower PPN bits must be zero
  if i > 0 {
    let mut level = 0
    while level < i {
      if pte_ppn_i(pte, level) != 0U.to_uint64() {
        return TranslateFault(fault)
      }
      level = level + 1
    }
  }
  // A/D bit checks
  if (pte & PTE_A) == 0U.to_uint64() {
    return TranslateFault(fault)
  }
  match access_type {
    Store =>
      if (pte & PTE_D) == 0U.to_uint64() {
        return TranslateFault(fault)
      }
    _ => ()
  }
  // Compute physical address
  let page_offset = vaddr & (SV39_PAGESIZE - 1U.to_uint64())
  let mut pa = pte_ppn(pte) * SV39_PAGESIZE + page_offset
  // For superpages, substitute VPN bits into PPN
  if i > 0 {
    let mut level = 0
    while level < i {
      let vpn_bits = sv39_vpn(vaddr, level)
      let shift = 12 + level * 9
      let mask = 0x1FFU.to_uint64() << shift
      pa = (pa & bit_not(mask)) | (vpn_bits << shift)
      level = level + 1
    }
  }
  TranslatedAddr(pa)
}

///|
fn Runner::satp_mode(self : Runner) -> UInt64 {
  match self.xlen_bits() {
    XLEN_64 => (self.cpu.read_csr(CSR_SATP) >> 60) & 0xfU.to_uint64()
    _ => 0U.to_uint64()
  }
}

///|
fn Runner::sv39_active_for_privilege(self : Runner, privilege : PrivilegeMode) -> Bool {
  match privilege {
    Machine => false
    _ => self.satp_mode() == 8U.to_uint64()
  }
}

///|
fn Runner::translate_address(
  self : Runner,
  vaddr : UInt64,
  access_type : AccessType,
  privilege : PrivilegeMode,
) -> TranslateResult {
  if !self.sv39_active_for_privilege(privilege) {
    return TranslatedAddr(vaddr)
  }
  let satp = self.cpu.read_csr(CSR_SATP)
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let sum = (mstatus & MSTATUS_SUM_BIT) != 0U.to_uint64()
  let mxr = (mstatus & MSTATUS_MXR_BIT) != 0U.to_uint64()
  sv39_translate(self.bus, satp, vaddr, access_type, privilege, sum, mxr)
}

///|
fn Runner::effective_data_access_privilege(self : Runner) -> PrivilegeMode {
  match self.cpu.privilege {
    Machine => ()
    _ => return self.cpu.privilege
  }
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  if (mstatus & MSTATUS_MPRV_BIT) == 0U.to_uint64() {
    return Machine
  }
  mstatus_mpp(mstatus)
}

///|
fn Runner::fetch_instruction(
  self : Runner,
  addr : UInt64,
) -> FetchedInstruction? {
  if !self.bus.contains_range(addr, 2) {
    return None
  }
  let low16 = self.bus.fetch_u16(addr)
  let length = instruction_length_from_low16(low16)
  if !self.bus.contains_range(addr, length) {
    return None
  }
  let raw = if length == 2 {
    low16
  } else {
    self.bus.fetch_u32(addr)
  }
  Some({ raw, length })
}

///|
fn Runner::address_from(self : Runner, rs1 : Int, imm : Int) -> UInt64 {
  self.cpu.read_reg(rs1) + int_to_uint64_bits(imm)
}

///|
fn Runner::load_check(self : Runner, addr : UInt64, width : Int) -> (UInt64, StepResult?) {
  let privilege = self.effective_data_access_privilege()
  let pa = match self.translate_address(addr, Load, privilege) {
    TranslatedAddr(pa) => pa
    TranslateFault(cause) =>
      return (addr, Some(self.raise_trap(cause, self.cpu.pc, addr)))
  }
  if self.phy_contains(pa, width) {
    (pa, None)
  } else {
    (addr, Some(self.raise_trap(LoadAccessFault, self.cpu.pc, addr)))
  }
}

///|
fn Runner::store_check(self : Runner, addr : UInt64, width : Int) -> (UInt64, StepResult?) {
  let privilege = self.effective_data_access_privilege()
  let pa = match self.translate_address(addr, Store, privilege) {
    TranslatedAddr(pa) => pa
    TranslateFault(cause) =>
      return (addr, Some(self.raise_trap(cause, self.cpu.pc, addr)))
  }
  if self.phy_contains(pa, width) {
    (pa, None)
  } else {
    (addr, Some(self.raise_trap(StoreAccessFault, self.cpu.pc, addr)))
  }
}

