// Sv39 page-table walking and translation cache support. Fault priority and
// permission checks should be kept aligned with the privileged architecture
// rather than with Linux observations alone.

///|
const PTE_V : UInt64 = 0x1

///|
const PTE_R : UInt64 = 0x2

///|
const PTE_W : UInt64 = 0x4

///|
const PTE_X : UInt64 = 0x8

///|
const PTE_U : UInt64 = 0x10

///|
const PTE_A : UInt64 = 0x40

///|
const PTE_D : UInt64 = 0x80

///|
const SV39_LEVELS : Int = 3

///|
const SV39_PAGESIZE : UInt64 = 4096

///|
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
  // Sv39 virtual addresses are sign-extended from bit 38. Rejecting
  // non-canonical addresses here keeps fetch/load/store fault behavior aligned
  // before any page table memory is touched.
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
  // This public pure-ish walker is used by tests and by Runner cache misses.
  // Keep side effects out of it; hardware-managed A/D updates are handled by
  // the Runner path that knows how to write guest memory and flush caches.
  let fault = access_type_fault(access_type)
  if !sv39_va_canonical(vaddr) {
    return TranslateFault(fault)
  }
  let mut a = satp_ppn(satp) * SV39_PAGESIZE
  let mut i = SV39_LEVELS - 1
  // Page table walk loop
  let mut pte = 0U.to_uint64()
  let mut leaf_pte_addr = 0U.to_uint64()
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
      leaf_pte_addr = pte_addr
      break
    }
    // Non-leaf: descend
    a = pte_ppn(pte) * SV39_PAGESIZE
    i = i - 1
    if i < 0 {
      return TranslateFault(fault)
    }
  } nobreak {
    return TranslateFault(
      // Loop exhausted without finding a leaf
      fault,
    )
  }
  // Leaf PTE found at level i
  // Permission checks
  match access_type {
    Fetch => if (pte & PTE_X) == 0U.to_uint64() { return TranslateFault(fault) }
    Load =>
      if (pte & PTE_R) == 0U.to_uint64() &&
        !(mxr && (pte & PTE_X) != 0U.to_uint64()) {
        return TranslateFault(fault)
      }
    Store => if (pte & PTE_W) == 0U.to_uint64() { return TranslateFault(fault) }
  }
  // U-bit check
  let is_user_page = (pte & PTE_U) != 0U.to_uint64()
  match privilege {
    User => if !is_user_page { return TranslateFault(fault) }
    Supervisor => if is_user_page && !sum { return TranslateFault(fault) }
    Machine => ()
  }
  // Superpage alignment: for level > 0, lower PPN bits must be zero
  if i > 0 {
    for level in 0..<i {
      if pte_ppn_i(pte, level) != 0U.to_uint64() {
        return TranslateFault(fault)
      }
    }
  }
  // This emulator exposes the common hardware-managed A/D-bit behavior rather
  // than Svade-style A/D page faults. Linux userspace relies on this path being
  // precise for stack writes and copy-on-write bookkeeping.
  let mut updated_pte = pte
  if (updated_pte & PTE_A) == 0U.to_uint64() {
    updated_pte = updated_pte | PTE_A
  }
  match access_type {
    Store =>
      if (updated_pte & PTE_D) == 0U.to_uint64() {
        updated_pte = updated_pte | PTE_D
      }
    _ => ()
  }
  if updated_pte != pte {
    bus.store_u64(leaf_pte_addr, updated_pte)
    pte = updated_pte
  }
  // Compute physical address
  let page_offset = vaddr & (SV39_PAGESIZE - 1U.to_uint64())
  let mut pa = pte_ppn(pte) * SV39_PAGESIZE + page_offset
  // For superpages, substitute VPN bits into PPN
  if i > 0 {
    for level in 0..<i {
      let vpn_bits = sv39_vpn(vaddr, level)
      let shift = 12 + level * 9
      let mask = 0x1FFU.to_uint64() << shift
      pa = (pa & bit_not(mask)) | (vpn_bits << shift)
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
fn Runner::sv39_active_for_privilege(
  self : Runner,
  privilege : PrivilegeMode,
) -> Bool {
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
  // Machine mode uses physical addressing for the OpenSBI path in this model.
  // S/U mode go through Sv39 only when satp.MODE says Sv39; Bare mode is still
  // useful for early kernel boot and low-level tests.
  if !self.sv39_active_for_privilege(privilege) {
    return TranslatedAddr(vaddr)
  }
  let satp = self.cpu.read_csr(CSR_SATP)
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let sum = (mstatus & MSTATUS_SUM_BIT) != 0U.to_uint64()
  let mxr = (mstatus & MSTATUS_MXR_BIT) != 0U.to_uint64()
  self.translate_cached(vaddr, access_type, privilege, satp, sum, mxr)
}

///|
fn translate_cache_access_id(access_type : AccessType) -> Int {
  match access_type {
    Fetch => 0
    Load => 1
    Store => 2
  }
}

///|
fn translate_cache_privilege_id(privilege : PrivilegeMode) -> Int {
  match privilege {
    User => 0
    Supervisor => 1
    Machine => 3
  }
}

///|
fn translate_cache_index(vpage : UInt64) -> Int {
  (vpage & (translate_cache_sets - 1).reinterpret_as_uint().to_uint64()).to_int()
}

///|
fn known_page_table_index(ppn : UInt64) -> Int {
  (ppn & (known_page_table_sets - 1).reinterpret_as_uint().to_uint64()).to_int()
}

///|
fn Runner::remember_page_table_page(self : Runner, pte_addr : UInt64) -> Unit {
  // Coarse page-table write tracking protects the translation cache from stale
  // PTEs without trying to implement full hardware TLB coherence. Guest stores
  // to a remembered page-table page flush cached translations.
  let ppn = pte_addr >> 12
  self.known_page_table_ppns[known_page_table_index(ppn)] = ppn
}

///|
fn Runner::record_page_table_walk(
  self : Runner,
  satp : UInt64,
  vaddr : UInt64,
) -> Unit {
  // Record every page-table page touched by the same walk shape used for
  // translation. This makes later guest PTE writes visible to the cache layer
  // even if Linux modifies a non-leaf table page.
  let mut a = satp_ppn(satp) * SV39_PAGESIZE
  let mut i = SV39_LEVELS - 1
  while i >= 0 {
    let pte_addr = a + sv39_vpn(vaddr, i) * SV39_PTESIZE
    if !self.bus.contains_range(pte_addr, 8) {
      return
    }
    self.remember_page_table_page(pte_addr)
    let pte = self.bus.load_u64(pte_addr)
    if (pte & PTE_V) == 0U.to_uint64() ||
      ((pte & PTE_R) == 0U.to_uint64() && (pte & PTE_W) != 0U.to_uint64()) {
      return
    }
    if (pte & PTE_R) != 0U.to_uint64() || (pte & PTE_X) != 0U.to_uint64() {
      return
    }
    a = pte_ppn(pte) * SV39_PAGESIZE
    i = i - 1
  }
}

///|
fn Runner::store_touches_known_page_table(
  self : Runner,
  pa : UInt64,
  width : Int,
) -> Bool {
  // Stores can span a page boundary. Check every touched physical page so a
  // wide guest store into page-table memory cannot leave stale translations.
  let start_ppn = pa >> 12
  let end_ppn = (pa + width.reinterpret_as_uint().to_uint64() - 1U.to_uint64()) >>
    12
  let mut ppn = start_ppn
  while ppn <= end_ppn {
    if self.known_page_table_ppns[known_page_table_index(ppn)] == ppn {
      return true
    }
    ppn = ppn + 1U.to_uint64()
  }
  false
}

///|
fn Runner::flush_translate_cache(self : Runner) -> Unit {
  for index in 0..<translate_cache_sets {
    self.translate_cache_vpages[index] = translate_cache_invalid_vpage
  }
  self.translate_cache_flushes = self.translate_cache_flushes + 1U.to_uint64()
}

///|
fn Runner::translate_cached(
  self : Runner,
  vaddr : UInt64,
  access_type : AccessType,
  privilege : PrivilegeMode,
  satp : UInt64,
  sum : Bool,
  mxr : Bool,
) -> TranslateResult {
  let page_offset = vaddr & (SV39_PAGESIZE - 1U.to_uint64())
  let vpage = vaddr >> 12
  let index = translate_cache_index(vpage)
  let access_id = translate_cache_access_id(access_type)
  let privilege_id = translate_cache_privilege_id(privilege)
  // Cache entries include access type, privilege, satp, SUM, and MXR because
  // the same virtual page can be legal for one access shape and fault for
  // another.
  if self.translate_cache_vpages[index] == vpage &&
    self.translate_cache_satps[index] == satp &&
    self.translate_cache_accesses[index] == access_id &&
    self.translate_cache_privileges[index] == privilege_id &&
    self.translate_cache_sums[index] == sum &&
    self.translate_cache_mxrs[index] == mxr {
    self.translate_cache_hits = self.translate_cache_hits + 1U.to_uint64()
    return TranslatedAddr(self.translate_cache_pa_pages[index] + page_offset)
  }
  self.translate_cache_misses = self.translate_cache_misses + 1U.to_uint64()
  self.record_page_table_walk(satp, vaddr)
  match
    sv39_translate(self.bus, satp, vaddr, access_type, privilege, sum, mxr) {
    TranslatedAddr(pa) => {
      self.translate_cache_vpages[index] = vpage
      self.translate_cache_satps[index] = satp
      self.translate_cache_accesses[index] = access_id
      self.translate_cache_privileges[index] = privilege_id
      self.translate_cache_sums[index] = sum
      self.translate_cache_mxrs[index] = mxr
      self.translate_cache_pa_pages[index] = pa - page_offset
      self.translate_cache_fills = self.translate_cache_fills + 1U.to_uint64()
      TranslatedAddr(pa)
    }
    TranslateFault(cause) => TranslateFault(cause)
  }
}

///|
fn Runner::effective_data_access_privilege(self : Runner) -> PrivilegeMode {
  // Loads/stores in M-mode can be translated as MPP when MPRV is set. This is
  // how firmware and kernels safely copy data using another privilege's view.
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
) -> (FetchedInstruction?, StepResult?) {
  // Fetch the low halfword first to determine instruction length. If the
  // instruction is 32-bit, translate pc+2 independently; a 32-bit instruction
  // can cross a virtual page boundary and land on a different physical page.
  let low_pa = match self.translate_address(addr, Fetch, self.cpu.privilege) {
    TranslatedAddr(pa) => pa
    TranslateFault(cause) =>
      return (None, Some(self.raise_trap(cause, addr, addr)))
  }
  if !self.bus.contains_range(low_pa, 2) {
    return (None, Some(self.raise_trap(InstructionAccessFault, addr, addr)))
  }
  let low16 = self.bus.fetch_u16(low_pa)
  let length = instruction_length_from_low16(low16)
  if length == 2 {
    return (Some({ fetch_pa: low_pa, raw: low16, length }), None)
  }
  let high_addr = addr + 2U.to_uint64()
  let high_pa = match
    self.translate_address(high_addr, Fetch, self.cpu.privilege) {
    TranslatedAddr(pa) => pa
    TranslateFault(cause) =>
      return (None, Some(self.raise_trap(cause, addr, high_addr)))
  }
  if !self.bus.contains_range(high_pa, 2) {
    return (
      None,
      Some(self.raise_trap(InstructionAccessFault, addr, high_addr)),
    )
  }
  let high16 = self.bus.fetch_u16(high_pa)
  (Some({ fetch_pa: low_pa, raw: low16 | (high16 << 16), length }), None)
}

///|
fn Runner::address_from(self : Runner, rs1 : Int, imm : Int) -> UInt64 {
  self.cpu.read_reg(rs1) + int_to_uint64_bits(imm)
}

///|
fn Runner::load_check(
  self : Runner,
  addr : UInt64,
  width : Int,
) -> (UInt64, StepResult?) {
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
fn Runner::store_check(
  self : Runner,
  addr : UInt64,
  width : Int,
) -> (UInt64, StepResult?) {
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
