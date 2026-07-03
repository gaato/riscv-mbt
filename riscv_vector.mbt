// RISC-V V extension support. This file intentionally grows in small slices:
// vsetvl state, first arithmetic/memory operations, then register grouping and
// broader addressing modes as the spec coverage expands.

///|
fn Runner::read_vcsr(self : Runner) -> UInt64 {
  self.cpu.read_csr(CSR_VCSR) & VCSR_VISIBLE_MASK
}

///|
fn Runner::write_vcsr(self : Runner, value : UInt64) -> Unit {
  let visible = value & VCSR_VISIBLE_MASK
  self.cpu.write_csr(CSR_VCSR, visible)
  self.cpu.write_csr(CSR_VXSAT, visible & VCSR_VXSAT_MASK)
  self.cpu.write_csr(CSR_VXRM, (visible & VCSR_VXRM_MASK) >> VCSR_VXRM_SHIFT)
}

///|
priv struct VectorVtypeConfig {
  // `normalized_vtype` preserves the guest-visible vtype bits after rejecting
  // unsupported or reserved encodings through vill.
  normalized_vtype : UInt64
  vsew_log2 : Int
  vlmul_log2 : Int
}

///|
fn vector_vill_value(xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => 1U.to_uint64() << 31
    XLEN_64 => 1U.to_uint64() << 63
    _ => abort("unsupported xlen for vector vill")
  }
}

///|
fn decode_vtype(requested_vtype : UInt64, xlen : Int) -> VectorVtypeConfig? {
  let vill = vector_vill_value(xlen)
  if (requested_vtype & vill) != 0U.to_uint64() {
    return None
  }
  if (requested_vtype & bit_not(0xffU.to_uint64())) != 0U.to_uint64() {
    return None
  }
  let vsew_log2 = ((requested_vtype >> 3) & 0x7U.to_uint64()).to_int()
  if vsew_log2 > 3 {
    return None
  }
  let vlmul_log2 = (requested_vtype & 0x7U.to_uint64()).to_int()
  if vlmul_log2 > 3 {
    return None
  }
  Some({
    normalized_vtype: requested_vtype & 0xffU.to_uint64(),
    vsew_log2,
    vlmul_log2,
  })
}

///|
fn encode_vtype(config : VectorVtypeConfig, _xlen : Int) -> UInt64 {
  config.normalized_vtype
}

///|
fn compute_vl(avl : UInt64, vsew_log2 : Int, vlmul_log2 : Int) -> UInt64 {
  let sew = 8U.to_uint64() << vsew_log2
  let lmul = 1U.to_uint64() << vlmul_log2
  let vlmax = VLEN_BYTES.to_uint64() * 8U.to_uint64() / sew * lmul
  if avl < vlmax {
    avl
  } else {
    vlmax
  }
}

///|
fn apply_vsetvl(
  avl : UInt64,
  requested_vtype : UInt64,
  xlen : Int,
) -> (UInt64, UInt64) {
  match decode_vtype(requested_vtype, xlen) {
    Some(config) =>
      (
        compute_vl(avl, config.vsew_log2, config.vlmul_log2),
        encode_vtype(config, xlen),
      )
    None => (0U.to_uint64(), vector_vill_value(xlen))
  }
}

///|
priv struct VectorExecConfig {
  // Decoded execution view for the current vector shape. `lmul_log2` is integer
  // LMUL in this implementation; fractional LMUL still goes through vill.
  vl : UInt64
  sew_bits : Int
  lmul_log2 : Int
}

///|
fn vector_elem_mask(sew_bits : Int) -> UInt64 {
  if sew_bits == 64 {
    bit_not(0U.to_uint64())
  } else {
    (1U.to_uint64() << sew_bits) - 1U.to_uint64()
  }
}

///|
fn Runner::current_vector_exec_config(self : Runner) -> VectorExecConfig? {
  match decode_vtype(self.cpu.read_csr(CSR_VTYPE), self.xlen_bits()) {
    Some(vtype) => {
      let sew_bits = 8 << vtype.vsew_log2
      Some({
        vl: self.cpu.read_csr(CSR_VL),
        sew_bits,
        lmul_log2: vtype.vlmul_log2,
      })
    }
    None => None
  }
}

///|
fn Runner::read_vreg_elem(
  self : Runner,
  vreg : Int,
  elem_index : Int,
  sew_bits : Int,
) -> UInt64 {
  let elems_per_word = 64 / sew_bits
  let word = elem_index / elems_per_word
  let elem_in_word = elem_index % elems_per_word
  let shift = elem_in_word * sew_bits
  (self.cpu.read_vreg(vreg, word) >> shift) & vector_elem_mask(sew_bits)
}

///|
fn Runner::write_vreg_elem(
  self : Runner,
  vreg : Int,
  elem_index : Int,
  sew_bits : Int,
  value : UInt64,
) -> Unit {
  let elems_per_word = 64 / sew_bits
  let word = elem_index / elems_per_word
  let elem_in_word = elem_index % elems_per_word
  let shift = elem_in_word * sew_bits
  let mask = vector_elem_mask(sew_bits) << shift
  let old_word = self.cpu.read_vreg(vreg, word)
  let next_word = (old_word & bit_not(mask)) |
    ((value & vector_elem_mask(sew_bits)) << shift)
  self.cpu.write_vreg(vreg, word, next_word)
}

///|
fn vector_lmul_registers(lmul_log2 : Int) -> Int {
  1 << lmul_log2
}

///|
fn vector_elems_per_register(sew_bits : Int) -> Int {
  VLEN_BYTES * 8 / sew_bits
}

///|
fn vector_group_aligned(vreg : Int, lmul_log2 : Int) -> Bool {
  let registers = vector_lmul_registers(lmul_log2)
  vreg % registers == 0 && vreg + registers <= VREG_COUNT
}

///|
fn vector_group_elem_vreg(
  base_vreg : Int,
  elem_index : Int,
  sew_bits : Int,
) -> (Int, Int) {
  // RVV packs a register group contiguously in element order. With VLEN=128,
  // SEW=32, and LMUL=2, elements 0..3 live in vN and 4..7 live in vN+1.
  let elems_per_register = vector_elems_per_register(sew_bits)
  let register_offset = elem_index / elems_per_register
  let local_elem = elem_index % elems_per_register
  (base_vreg + register_offset, local_elem)
}

///|
fn Runner::read_vreg_group_elem(
  self : Runner,
  base_vreg : Int,
  elem_index : Int,
  sew_bits : Int,
) -> UInt64 {
  let (vreg, local_elem) = vector_group_elem_vreg(
    base_vreg, elem_index, sew_bits,
  )
  self.read_vreg_elem(vreg, local_elem, sew_bits)
}

///|
fn Runner::write_vreg_group_elem(
  self : Runner,
  base_vreg : Int,
  elem_index : Int,
  sew_bits : Int,
  value : UInt64,
) -> Unit {
  let (vreg, local_elem) = vector_group_elem_vreg(
    base_vreg, elem_index, sew_bits,
  )
  self.write_vreg_elem(vreg, local_elem, sew_bits, value)
}

///|
fn Runner::read_vmask_bit(self : Runner, elem_index : Int) -> Bool {
  let word = elem_index / 64
  let bit = elem_index % 64
  ((self.cpu.read_vreg(0, word) >> bit) & 1U.to_uint64()) != 0U.to_uint64()
}

///|
fn Runner::vector_exec_supported(self : Runner) -> VectorExecConfig? {
  match self.current_vector_exec_config() {
    Some(config) =>
      if config.lmul_log2 == 0 &&
        self.cpu.read_csr(CSR_VSTART) == 0U.to_uint64() {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn Runner::vector_memory_exec_config(self : Runner) -> VectorExecConfig? {
  match self.current_vector_exec_config() {
    Some(config) =>
      if config.lmul_log2 <= 1 &&
        self.cpu.read_csr(CSR_VSTART) == 0U.to_uint64() {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn Runner::vector_memory_group_config(
  self : Runner,
  vreg : Int,
  elem_bytes : Int,
) -> VectorExecConfig? {
  match self.vector_memory_exec_config() {
    Some(config) =>
      if config.sew_bits == elem_bytes * 8 &&
        vector_group_aligned(vreg, config.lmul_log2) {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn Runner::vector_mask_memory_config(self : Runner) -> VectorExecConfig? {
  match self.current_vector_exec_config() {
    Some(config) =>
      if self.cpu.read_csr(CSR_VSTART) == 0U.to_uint64() {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn vector_mask_memory_bytes(vl : UInt64) -> Int {
  ((vl + 7U.to_uint64()) / 8U.to_uint64()).reinterpret_as_int64().to_int()
}

///|
fn Runner::vector_indexed_e32_config(
  self : Runner,
  data_vreg : Int,
  index_vreg : Int,
) -> VectorExecConfig? {
  match self.vector_memory_group_config(data_vreg, 4) {
    Some(config) =>
      // This first indexed slice supports only data SEW=32 with index EEW=32,
      // so the index EMUL matches the current LMUL.
      if config.sew_bits == 32 &&
        vector_group_aligned(index_vreg, config.lmul_log2) {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn vector_unit_stride_addr(
  base : UInt64,
  elem_index : Int,
  elem_bytes : Int,
) -> UInt64 {
  base +
  elem_index.reinterpret_as_uint().to_uint64() *
  elem_bytes.reinterpret_as_uint().to_uint64()
}

///|
fn vector_strided_addr(
  base : UInt64,
  elem_index : Int,
  stride : UInt64,
) -> UInt64 {
  base + elem_index.reinterpret_as_uint().to_uint64() * stride
}

///|
fn vector_indexed_addr(base : UInt64, offset : UInt64) -> UInt64 {
  base + offset
}

///|
fn Runner::vector_load_elem_bits(
  self : Runner,
  pa : UInt64,
  elem_bytes : Int,
) -> UInt64 {
  match elem_bytes {
    1 => self.phy_load_u8(pa)
    2 => self.phy_load_u16(pa)
    4 => self.phy_load_u32(pa)
    8 => self.phy_load_u64(pa)
    _ => abort("unsupported vector load element width")
  }
}

///|
fn Runner::vector_store_elem_bits(
  self : Runner,
  pa : UInt64,
  elem_bytes : Int,
  value : UInt64,
) -> Unit {
  match elem_bytes {
    1 => self.phy_store_u8(pa, value)
    2 => self.phy_store_u16(pa, value)
    4 => self.phy_store_u32(pa, value)
    8 => self.phy_store_u64(pa, value)
    _ => abort("unsupported vector store element width")
  }
}

///|
fn Runner::execute_vector_load_unit_stride(
  self : Runner,
  vd : Int,
  rs1 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vd, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let addr = vector_unit_stride_addr(base, elem, elem_bytes)
    let (pa, check) = self.load_check(addr, elem_bytes)
    match check {
      Some(result) => return result
      None => pas.push(pa)
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_elem in 0..<active_elems {
    self.write_vreg_group_elem(vd, commit_elem, sew_bits, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_load_strided(
  self : Runner,
  vd : Int,
  rs1 : Int,
  rs2 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vd, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let stride = self.cpu.read_reg(rs2)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let addr = vector_strided_addr(base, elem, stride)
    let (pa, check) = self.load_check(addr, elem_bytes)
    match check {
      Some(result) => return result
      None => pas.push(pa)
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_elem in 0..<active_elems {
    self.write_vreg_group_elem(vd, commit_elem, sew_bits, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_load_indexed_e32(
  self : Runner,
  vd : Int,
  rs1 : Int,
  vs2 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_indexed_e32_config(vd, vs2) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let elem_bytes = 4
  let sew_bits = 32
  let index_bits = 32
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let offset = self.read_vreg_group_elem(vs2, elem, index_bits)
    let addr = vector_indexed_addr(base, offset)
    let (pa, check) = self.load_check(addr, elem_bytes)
    match check {
      Some(result) => return result
      None => pas.push(pa)
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_elem in 0..<active_elems {
    self.write_vreg_group_elem(vd, commit_elem, sew_bits, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_load(
  self : Runner,
  vd : Int,
  rs1 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_mask_memory_config() {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let active_bytes = vector_mask_memory_bytes(config.vl)
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_bytes {
    let addr = vector_unit_stride_addr(base, elem, 1)
    let (pa, check) = self.load_check(addr, 1)
    match check {
      Some(result) => return result
      None => pas.push(pa)
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, 1))
  }
  for commit_elem in 0..<active_bytes {
    self.write_vreg_elem(vd, commit_elem, 8, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_unit_stride(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vs3, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let addr = vector_unit_stride_addr(base, elem, elem_bytes)
    let (pa, check) = self.store_check(addr, elem_bytes)
    match check {
      Some(result) => return result
      None => {
        pas.push(pa)
        values.push(self.read_vreg_group_elem(vs3, elem, sew_bits))
      }
    }
  }
  for commit_elem in 0..<active_elems {
    self.vector_store_elem_bits(
      pas[commit_elem],
      elem_bytes,
      values[commit_elem],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_store(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_mask_memory_config() {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let active_bytes = vector_mask_memory_bytes(config.vl)
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_bytes {
    let addr = vector_unit_stride_addr(base, elem, 1)
    let (pa, check) = self.store_check(addr, 1)
    match check {
      Some(result) => return result
      None => {
        pas.push(pa)
        values.push(self.read_vreg_elem(vs3, elem, 8))
      }
    }
  }
  for commit_elem in 0..<active_bytes {
    self.vector_store_elem_bits(pas[commit_elem], 1, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_indexed_e32(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  vs2 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_indexed_e32_config(vs3, vs2) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let elem_bytes = 4
  let sew_bits = 32
  let index_bits = 32
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let offset = self.read_vreg_group_elem(vs2, elem, index_bits)
    let addr = vector_indexed_addr(base, offset)
    let (pa, check) = self.store_check(addr, elem_bytes)
    match check {
      Some(result) => return result
      None => {
        pas.push(pa)
        values.push(self.read_vreg_group_elem(vs3, elem, sew_bits))
      }
    }
  }
  for commit_elem in 0..<active_elems {
    self.vector_store_elem_bits(
      pas[commit_elem],
      elem_bytes,
      values[commit_elem],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_strided(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  rs2 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vs3, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let stride = self.cpu.read_reg(rs2)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let addr = vector_strided_addr(base, elem, stride)
    let (pa, check) = self.store_check(addr, elem_bytes)
    match check {
      Some(result) => return result
      None => {
        pas.push(pa)
        values.push(self.read_vreg_group_elem(vs3, elem, sew_bits))
      }
    }
  }
  for commit_elem in 0..<active_elems {
    self.vector_store_elem_bits(
      pas[commit_elem],
      elem_bytes,
      values[commit_elem],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::vector_avl_from_rs1_rd(self : Runner, rs1 : Int, rd : Int) -> UInt64 {
  if rs1 != 0 {
    self.cpu.read_reg(rs1)
  } else if rd != 0 {
    bit_not(0U.to_uint64())
  } else {
    self.cpu.read_csr(CSR_VL)
  }
}

///|
fn Runner::execute_vsetvl(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let (rd, avl, requested_vtype) = match instruction {
    Vsetvli(rd, rs1, vtypei) =>
      (rd, self.vector_avl_from_rs1_rd(rs1, rd), vtypei.to_uint64())
    Vsetivli(rd, avl, vtypei) => (rd, avl.to_uint64(), vtypei.to_uint64())
    Vsetvl(rd, rs1, rs2) =>
      (rd, self.vector_avl_from_rs1_rd(rs1, rd), self.cpu.read_reg(rs2))
    _ => abort("unexpected vsetvl dispatch")
  }
  let (vl, vtype) = apply_vsetvl(avl, requested_vtype, self.xlen_bits())
  self.cpu.write_csr(CSR_VL, vl)
  self.cpu.write_csr(CSR_VTYPE, vtype)
  self.cpu.write_csr(CSR_VSTART, 0U.to_uint64())
  self.write_xlen_reg(rd, vl)
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_first_slice(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_exec_supported() {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let sew_mask = vector_elem_mask(config.sew_bits)
  let use_mask = ((raw >> 25) & 0x1U) == 0U
  let mask_bits : Array[Bool] = []
  if use_mask {
    for elem in 0..<active_elems {
      mask_bits.push(self.read_vmask_bit(elem))
    }
  }
  match instruction {
    VmvVI(vd, imm) => {
      let value = int_to_uint64_bits(imm) & sew_mask
      for elem in 0..<active_elems {
        self.write_vreg_elem(vd, elem, config.sew_bits, value)
      }
      self.cpu.pc = next_pc
      Running
    }
    VmvVX(vd, rs1) => {
      let value = self.cpu.read_reg(rs1) & sew_mask
      for elem in 0..<active_elems {
        self.write_vreg_elem(vd, elem, config.sew_bits, value)
      }
      self.cpu.pc = next_pc
      Running
    }
    VmvXS(rd, vs2) => {
      self.write_xlen_reg(
        rd,
        xlen_sign_extend(
          self.read_vreg_elem(vs2, 0, config.sew_bits),
          config.sew_bits,
          self.xlen_bits(),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    VaddVv(vd, vs2, vs1) => {
      for elem in 0..<active_elems {
        if !use_mask || mask_bits[elem] {
          let lhs = self.read_vreg_elem(vs2, elem, config.sew_bits)
          let rhs = self.read_vreg_elem(vs1, elem, config.sew_bits)
          self.write_vreg_elem(
            vd,
            elem,
            config.sew_bits,
            (lhs + rhs) & sew_mask,
          )
        }
      }
      self.cpu.pc = next_pc
      Running
    }
    VaddVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      for elem in 0..<active_elems {
        if !use_mask || mask_bits[elem] {
          let lhs = self.read_vreg_elem(vs2, elem, config.sew_bits)
          self.write_vreg_elem(
            vd,
            elem,
            config.sew_bits,
            (lhs + scalar) & sew_mask,
          )
        }
      }
      self.cpu.pc = next_pc
      Running
    }
    VaddVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      for elem in 0..<active_elems {
        if !use_mask || mask_bits[elem] {
          let lhs = self.read_vreg_elem(vs2, elem, config.sew_bits)
          self.write_vreg_elem(
            vd,
            elem,
            config.sew_bits,
            (lhs + scalar) & sew_mask,
          )
        }
      }
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected vector first-slice dispatch")
  }
}

///|
fn Runner::execute_vector_memory_first_slice(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    VlmV(vd, rs1) =>
      self.execute_vector_mask_load(vd, rs1, current_pc, next_pc, raw)
    Vle8V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 1, current_pc, next_pc, raw)
    Vle16V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 2, current_pc, next_pc, raw)
    Vle32V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 4, current_pc, next_pc, raw)
    Vle64V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 8, current_pc, next_pc, raw)
    Vluxei32V(vd, rs1, vs2) =>
      self.execute_vector_load_indexed_e32(
        vd, rs1, vs2, current_pc, next_pc, raw,
      )
    Vloxei32V(vd, rs1, vs2) =>
      self.execute_vector_load_indexed_e32(
        vd, rs1, vs2, current_pc, next_pc, raw,
      )
    Vlse32V(vd, rs1, rs2) =>
      self.execute_vector_load_strided(
        vd, rs1, rs2, 4, current_pc, next_pc, raw,
      )
    VsmV(vs3, rs1) =>
      self.execute_vector_mask_store(vs3, rs1, current_pc, next_pc, raw)
    Vse8V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 1, current_pc, next_pc, raw,
      )
    Vse16V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 2, current_pc, next_pc, raw,
      )
    Vse32V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 4, current_pc, next_pc, raw,
      )
    Vse64V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 8, current_pc, next_pc, raw,
      )
    Vsuxei32V(vs3, rs1, vs2) =>
      self.execute_vector_store_indexed_e32(
        vs3, rs1, vs2, current_pc, next_pc, raw,
      )
    Vsoxei32V(vs3, rs1, vs2) =>
      self.execute_vector_store_indexed_e32(
        vs3, rs1, vs2, current_pc, next_pc, raw,
      )
    Vsse32V(vs3, rs1, rs2) =>
      self.execute_vector_store_strided(
        vs3, rs1, rs2, 4, current_pc, next_pc, raw,
      )
    _ => abort("unexpected vector memory first-slice dispatch")
  }
}
