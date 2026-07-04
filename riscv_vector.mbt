// RISC-V V extension support. This file intentionally grows in small slices:
// vsetvl state, first arithmetic/memory operations, then register grouping and
// broader addressing modes as the spec coverage expands.

///|
fn Runner::read_vcsr(self : Runner) -> UInt64 {
  self.cpu.read_csr(CSR_VCSR) & VCSR_VISIBLE_MASK
}

///|
fn Runner::write_vcsr(self : Runner, value : UInt64) -> Unit {
  // vcsr is the combined guest-visible CSR; vxsat/vxrm are aliases. Writing
  // one backing value here keeps CSR reads consistent regardless of which
  // architectural alias Linux or a test touches.
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
fn decode_vlmul(raw_vlmul : Int) -> Int? {
  if raw_vlmul <= 3 {
    Some(raw_vlmul)
  } else if raw_vlmul == 4 {
    None
  } else {
    Some(raw_vlmul - 8)
  }
}

///|
fn vector_fractional_lmul_supports_sew(
  vlmul_log2 : Int,
  sew_bits : Int,
) -> Bool {
  // This implementation exposes ELEN=64. The V spec requires fractional LMUL
  // values down to 1/8 for ELEN=64, but a fractional setting is only usable for
  // SEW values that fit in LMUL*ELEN.
  vlmul_log2 >= 0 || sew_bits <= 64 >> -vlmul_log2
}

///|
fn decode_vtype(requested_vtype : UInt64, xlen : Int) -> VectorVtypeConfig? {
  // Unsupported shapes return None so callers can write vill and set vl=0.
  // That keeps the visible CSR behavior separate from individual instruction
  // dispatch decisions.
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
  let raw_vlmul = (requested_vtype & 0x7U.to_uint64()).to_int()
  let vlmul_log2 = match decode_vlmul(raw_vlmul) {
    Some(value) => value
    None => return None
  }
  let sew_bits = 8 << vsew_log2
  if !vector_fractional_lmul_supports_sew(vlmul_log2, sew_bits) {
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
  // This emulator currently exposes VLEN=128 bits. VL is min(AVL, VLMAX),
  // with fractional LMUL reducing the element capacity instead of allocating
  // fractional register storage.
  let sew = 8U.to_uint64() << vsew_log2
  let elems_per_register = VLEN_BYTES.to_uint64() * 8U.to_uint64() / sew
  let vlmax = if vlmul_log2 >= 0 {
    elems_per_register * (1U.to_uint64() << vlmul_log2)
  } else {
    elems_per_register / (1U.to_uint64() << -vlmul_log2)
  }
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
  // Decoded execution view for the current vector shape. `lmul_log2` is the
  // signed log2(LMUL), so mf2/mf4/mf8 are represented as -1/-2/-3.
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
  if lmul_log2 <= 0 {
    1
  } else {
    1 << lmul_log2
  }
}

///|
fn vector_elems_per_register(sew_bits : Int) -> Int {
  VLEN_BYTES * 8 / sew_bits
}

///|
fn vector_group_aligned(vreg : Int, lmul_log2 : Int) -> Bool {
  // For LMUL>1 the base register must be aligned to the group size and the
  // whole group must fit inside v0..v31. Fractional LMUL still occupies one
  // physical register in this representation.
  let registers = vector_lmul_registers(lmul_log2)
  vreg % registers == 0 && vreg + registers <= VREG_COUNT
}

///|
fn vector_group_contains_vreg(
  base_vreg : Int,
  lmul_log2 : Int,
  vreg : Int,
) -> Bool {
  let registers = vector_lmul_registers(lmul_log2)
  base_vreg <= vreg && vreg < base_vreg + registers
}

///|
fn vector_group_elem_vreg(
  base_vreg : Int,
  elem_index : Int,
  sew_bits : Int,
) -> (Int, Int) {
  // RVV packs a register group contiguously in element order. With VLEN=128,
  // SEW=32, and LMUL=2, elements 0..3 live in vN and 4..7 live in vN+1.
  // Fractional LMUL values still use a single architectural vector register;
  // vsetvl clamps vl so only the low fraction of that register is active.
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
  self.read_vmask_bit_from(0, elem_index)
}

///|
fn Runner::read_vmask_bit_from(
  self : Runner,
  vreg : Int,
  elem_index : Int,
) -> Bool {
  let word = elem_index / 64
  let bit = elem_index % 64
  ((self.cpu.read_vreg(vreg, word) >> bit) & 1U.to_uint64()) != 0U.to_uint64()
}

///|
fn Runner::write_vmask_bit(
  self : Runner,
  vreg : Int,
  elem_index : Int,
  value : Bool,
) -> Unit {
  let word = elem_index / 64
  let bit = elem_index % 64
  let bit_mask = 1U.to_uint64() << bit
  let old_word = self.cpu.read_vreg(vreg, word)
  let next_word = if value {
    old_word | bit_mask
  } else {
    old_word & bit_not(bit_mask)
  }
  self.cpu.write_vreg(vreg, word, next_word)
}

///|
fn Runner::vector_exec_supported(self : Runner) -> VectorExecConfig? {
  // The current RVV executor supports a practical subset with vstart=0. Keeping
  // the guard centralized makes every slice fail the same way for unsupported
  // restart semantics.
  match self.current_vector_exec_config() {
    Some(config) =>
      // This execute slice supports the required LMUL range mf8..m8. Fractional
      // LMULs use one register while vsetvl limits VLMAX to the active fraction.
      // It still rejects nonzero vstart because restart semantics need a
      // separate fault/replay contract before Linux-facing vector state can
      // rely on it.
      if config.lmul_log2 <= 3 &&
        self.cpu.read_csr(CSR_VSTART) == 0U.to_uint64() {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn Runner::vector_whole_register_move_supported(
  self : Runner,
) -> VectorExecConfig? {
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
fn Runner::raise_vector_group_misaligned(
  self : Runner,
  current_pc : UInt64,
  raw : UInt,
) -> StepResult {
  // RVV register groups must start at a register number aligned to the group
  // size. For the first LMUL>1 slice that means m2 operations can use v2-v3
  // but must reject a base such as v3.
  self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
}

///|
priv enum VectorBinaryOp {
  VectorBinAdd
  VectorBinSub
  VectorBinRsub
  VectorBinMul
  VectorBinMinu
  VectorBinMin
  VectorBinMaxu
  VectorBinMax
  VectorBinSll
  VectorBinSrl
  VectorBinSra
  VectorBinAnd
  VectorBinOr
  VectorBinXor
}

///|
priv enum VectorCompareOp {
  VectorCmpEq
  VectorCmpNe
  VectorCmpLtu
  VectorCmpLt
  VectorCmpLeu
  VectorCmpLe
  VectorCmpGtu
  VectorCmpGt
}

///|
priv enum VectorMaskLogicalOp {
  VectorMaskAnd
  VectorMaskNand
  VectorMaskAndNot
  VectorMaskXor
  VectorMaskOr
  VectorMaskNor
  VectorMaskOrNot
  VectorMaskXnor
}

///|
priv enum VectorMaskPrefixOp {
  VectorMaskSetBeforeFirst
  VectorMaskSetIncludingFirst
  VectorMaskSetOnlyFirst
}

///|
fn vector_signed_lane(value : UInt64, sew_bits : Int) -> Int64 {
  // Signed RVV integer comparisons interpret each lane at SEW width, not at
  // host UInt64 width. Sign-extend before comparing so e32 0xffffffff is -1.
  xlen_sign_extend(value, sew_bits, XLEN_64).reinterpret_as_int64()
}

///|
fn vector_shift_amount(value : UInt64, sew_bits : Int) -> Int {
  // RVV single-width shifts use only the low lg2(SEW) bits. Because all
  // currently supported SEW values are powers of two, `SEW - 1` is that mask.
  (value & (sew_bits - 1).reinterpret_as_uint().to_uint64()).to_int()
}

///|
fn vector_apply_binary(
  lhs : UInt64,
  rhs : UInt64,
  op : VectorBinaryOp,
  sew_bits : Int,
) -> UInt64 {
  match op {
    VectorBinAdd => lhs + rhs
    VectorBinSub => lhs - rhs
    // Reverse subtract is only encoded for vector-scalar/immediate forms; keep
    // it as a named operation so `scalar - vs2[i]` is visible at the call site.
    VectorBinRsub => rhs - lhs
    // `vmul` returns the low SEW bits of the full product. The shared binary
    // executor applies `sew_mask` after this helper, which keeps each lane's
    // low half and discards any upper product bits.
    VectorBinMul => lhs * rhs
    VectorBinMinu => if lhs < rhs { lhs } else { rhs }
    VectorBinMin =>
      if vector_signed_lane(lhs, sew_bits) < vector_signed_lane(rhs, sew_bits) {
        lhs
      } else {
        rhs
      }
    VectorBinMaxu => if lhs > rhs { lhs } else { rhs }
    VectorBinMax =>
      if vector_signed_lane(lhs, sew_bits) > vector_signed_lane(rhs, sew_bits) {
        lhs
      } else {
        rhs
      }
    VectorBinSll => lhs << vector_shift_amount(rhs, sew_bits)
    VectorBinSrl => lhs >> vector_shift_amount(rhs, sew_bits)
    VectorBinSra => {
      let shifted = vector_signed_lane(lhs, sew_bits) >>
        vector_shift_amount(rhs, sew_bits)
      shifted.reinterpret_as_uint64()
    }
    VectorBinAnd => lhs & rhs
    VectorBinOr => lhs | rhs
    VectorBinXor => lhs ^ rhs
  }
}

///|
fn vector_apply_compare(
  lhs : UInt64,
  rhs : UInt64,
  op : VectorCompareOp,
  sew_bits : Int,
) -> Bool {
  match op {
    VectorCmpEq => lhs == rhs
    VectorCmpNe => lhs != rhs
    VectorCmpLtu => lhs < rhs
    VectorCmpLt =>
      vector_signed_lane(lhs, sew_bits) < vector_signed_lane(rhs, sew_bits)
    VectorCmpLeu => lhs <= rhs
    VectorCmpLe =>
      vector_signed_lane(lhs, sew_bits) <= vector_signed_lane(rhs, sew_bits)
    VectorCmpGtu => lhs > rhs
    VectorCmpGt =>
      vector_signed_lane(lhs, sew_bits) > vector_signed_lane(rhs, sew_bits)
  }
}

///|
fn vector_apply_mask_logical(
  lhs : Bool,
  rhs : Bool,
  op : VectorMaskLogicalOp,
) -> Bool {
  match op {
    VectorMaskAnd => lhs && rhs
    VectorMaskNand => !(lhs && rhs)
    VectorMaskAndNot => lhs && !rhs
    VectorMaskXor => lhs != rhs
    VectorMaskOr => lhs || rhs
    VectorMaskNor => !(lhs || rhs)
    VectorMaskOrNot => lhs || !rhs
    VectorMaskXnor => lhs == rhs
  }
}

///|
fn Runner::execute_vector_mask_logical(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  op : VectorMaskLogicalOp,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if self.cpu.read_csr(CSR_VSTART) != 0U.to_uint64() {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  for elem in 0..<active_elems {
    let lhs = self.read_vmask_bit_from(vs2, elem)
    let rhs = self.read_vmask_bit_from(vs1, elem)
    self.write_vmask_bit(vd, elem, vector_apply_mask_logical(lhs, rhs, op))
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_prefix(
  self : Runner,
  vd : Int,
  vs2 : Int,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorMaskPrefixOp,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  // These instructions scan the source mask, and masked forms also read v0.
  // Reject destination overlap so writes cannot disturb later source bits.
  if vd == vs2 || (use_mask && vd == 0) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let mut found = false
  for elem in 0..<active_elems {
    if use_mask && !mask_bits[elem] {
      continue
    }
    let source_set = self.read_vmask_bit_from(vs2, elem)
    let value = match op {
      VectorMaskSetBeforeFirst => !found && !source_set
      VectorMaskSetIncludingFirst => !found
      VectorMaskSetOnlyFirst => !found && source_set
    }
    self.write_vmask_bit(vd, elem, value)
    if source_set {
      found = true
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_iota(
  self : Runner,
  vd : Int,
  vs2 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  if vector_group_contains_vreg(vd, config.lmul_log2, vs2) ||
    (use_mask && vector_group_contains_vreg(vd, config.lmul_log2, 0)) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let mut count = 0U.to_uint64()
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      self.write_vreg_group_elem(vd, elem, config.sew_bits, count)
      if self.read_vmask_bit_from(vs2, elem) {
        count += 1U.to_uint64()
      }
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_index(
  self : Runner,
  vd : Int,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      self.write_vreg_group_elem(
        vd,
        elem,
        config.sew_bits,
        elem.reinterpret_as_uint().to_uint64(),
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_count(
  self : Runner,
  rd : Int,
  vs2 : Int,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  next_pc : UInt64,
) -> StepResult {
  let mut count = 0U.to_uint64()
  for elem in 0..<active_elems {
    if (!use_mask || mask_bits[elem]) && self.read_vmask_bit_from(vs2, elem) {
      count += 1U.to_uint64()
    }
  }
  self.write_xlen_reg(rd, count)
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_first(
  self : Runner,
  rd : Int,
  vs2 : Int,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  next_pc : UInt64,
) -> StepResult {
  let not_found = bit_not(0U.to_uint64())
  let found = for elem in 0..<active_elems; current = not_found {
    if current == not_found &&
      (!use_mask || mask_bits[elem]) &&
      self.read_vmask_bit_from(vs2, elem) {
      continue elem.reinterpret_as_uint().to_uint64()
    }
    continue current
  } nobreak {
    current
  }
  self.write_xlen_reg(rd, found)
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_compare_vv(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorCompareOp,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vs2, config.lmul_log2) ||
    !vector_group_aligned(vs1, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let lhs = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      let rhs = self.read_vreg_group_elem(vs1, elem, config.sew_bits)
      self.write_vmask_bit(
        vd,
        elem,
        vector_apply_compare(lhs, rhs, op, config.sew_bits),
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_compare_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorCompareOp,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let lhs = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      self.write_vmask_bit(
        vd,
        elem,
        vector_apply_compare(lhs, scalar, op, config.sew_bits),
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_binary_vv(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorBinaryOp,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) ||
    !vector_group_aligned(vs1, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let lhs = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      let rhs = self.read_vreg_group_elem(vs1, elem, config.sew_bits)
      self.write_vreg_group_elem(
        vd,
        elem,
        config.sew_bits,
        vector_apply_binary(lhs, rhs, op, config.sew_bits) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_binary_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorBinaryOp,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let lhs = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      self.write_vreg_group_elem(
        vd,
        elem,
        config.sew_bits,
        vector_apply_binary(lhs, scalar, op, config.sew_bits) & sew_mask,
      )
    }
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
  match instruction {
    VmvNrR(vd, vs2, nreg) =>
      return self.execute_vector_whole_register_move(
        vd, vs2, nreg, current_pc, next_pc, raw,
      )
    _ => ()
  }
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
  match
    self.execute_vector_permutation_dispatch(
      instruction, config, active_elems, sew_mask, mask_bits, use_mask, current_pc,
      next_pc, raw,
    ) {
    Some(result) => return result
    None => ()
  }
  match instruction {
    VmvVI(vd, imm) => {
      if !vector_group_aligned(vd, config.lmul_log2) {
        return self.raise_vector_group_misaligned(current_pc, raw)
      }
      let value = int_to_uint64_bits(imm) & sew_mask
      for elem in 0..<active_elems {
        self.write_vreg_group_elem(vd, elem, config.sew_bits, value)
      }
      self.cpu.pc = next_pc
      Running
    }
    VmvVX(vd, rs1) => {
      if !vector_group_aligned(vd, config.lmul_log2) {
        return self.raise_vector_group_misaligned(current_pc, raw)
      }
      let value = self.cpu.read_reg(rs1) & sew_mask
      for elem in 0..<active_elems {
        self.write_vreg_group_elem(vd, elem, config.sew_bits, value)
      }
      self.cpu.pc = next_pc
      Running
    }
    VmvVV(vd, vs1) =>
      self.execute_vector_move_vv(
        vd, vs1, config, active_elems, current_pc, next_pc, raw,
      )
    VmvXS(rd, vs2) => {
      if !vector_group_aligned(vs2, config.lmul_log2) {
        return self.raise_vector_group_misaligned(current_pc, raw)
      }
      self.write_xlen_reg(
        rd,
        xlen_sign_extend(
          self.read_vreg_group_elem(vs2, 0, config.sew_bits),
          config.sew_bits,
          self.xlen_bits(),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    VmergeVvm(vd, vs2, vs1) =>
      self.execute_vector_merge_vv(
        vd, vs2, vs1, config, active_elems, current_pc, next_pc, raw,
      )
    VmergeVxm(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_merge_scalar(
        vd, vs2, scalar, config, active_elems, current_pc, next_pc, raw,
      )
    }
    VmergeVim(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_merge_scalar(
        vd, vs2, scalar, config, active_elems, current_pc, next_pc, raw,
      )
    }
    VaddVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinAdd,
        current_pc,
        next_pc,
        raw,
      )
    VaddVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinAdd,
        current_pc,
        next_pc,
        raw,
      )
    }
    VaddVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinAdd,
        current_pc,
        next_pc,
        raw,
      )
    }
    VsubVv(vd, vs2, vs1) =>
      // RVV integer subtract is modulo the active SEW, just like add. Keep the
      // mask after the arithmetic so narrower SEW lanes wrap independently.
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSub,
        current_pc,
        next_pc,
        raw,
      )
    VsubVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSub,
        current_pc,
        next_pc,
        raw,
      )
    }
    VrsubVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinRsub,
        current_pc,
        next_pc,
        raw,
      )
    }
    VrsubVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinRsub,
        current_pc,
        next_pc,
        raw,
      )
    }
    VwadduVv(_, _, _)
    | VwadduVx(_, _, _)
    | VwaddVv(_, _, _)
    | VwaddVx(_, _, _)
    | VwsubuVv(_, _, _)
    | VwsubuVx(_, _, _)
    | VwsubVv(_, _, _)
    | VwsubVx(_, _, _) =>
      self.execute_vector_widening_instruction(
        instruction, config, active_elems, mask_bits, use_mask, current_pc, next_pc,
        raw,
      )
    VmulVv(_, _, _)
    | VmulVx(_, _, _)
    | VmulhuVv(_, _, _)
    | VmulhuVx(_, _, _)
    | VmulhVv(_, _, _)
    | VmulhVx(_, _, _)
    | VmulhsuVv(_, _, _)
    | VmulhsuVx(_, _, _) =>
      self.execute_vector_multiply_instruction(
        instruction, config, active_elems, sew_mask, mask_bits, use_mask, current_pc,
        next_pc, raw,
      )
    VdivuVv(_, _, _)
    | VdivuVx(_, _, _)
    | VdivVv(_, _, _)
    | VdivVx(_, _, _)
    | VremuVv(_, _, _)
    | VremuVx(_, _, _)
    | VremVv(_, _, _)
    | VremVx(_, _, _) =>
      self.execute_vector_divide_instruction(
        instruction, config, active_elems, sew_mask, mask_bits, use_mask, current_pc,
        next_pc, raw,
      )
    VminuVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMinu,
        current_pc,
        next_pc,
        raw,
      )
    VminuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMinu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VminVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMin,
        current_pc,
        next_pc,
        raw,
      )
    VminVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMin,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmaxuVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMaxu,
        current_pc,
        next_pc,
        raw,
      )
    VmaxuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMaxu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmaxVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMax,
        current_pc,
        next_pc,
        raw,
      )
    VmaxVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMax,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmseqVv(vd, vs2, vs1) =>
      self.execute_vector_compare_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpEq,
        current_pc,
        next_pc,
        raw,
      )
    VmseqVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpEq,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmseqVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpEq,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsneVv(vd, vs2, vs1) =>
      self.execute_vector_compare_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpNe,
        current_pc,
        next_pc,
        raw,
      )
    VmsneVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpNe,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsneVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpNe,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsltuVv(vd, vs2, vs1) =>
      self.execute_vector_compare_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLtu,
        current_pc,
        next_pc,
        raw,
      )
    VmsltuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLtu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsltVv(vd, vs2, vs1) =>
      self.execute_vector_compare_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLt,
        current_pc,
        next_pc,
        raw,
      )
    VmsltVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLt,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsleuVv(vd, vs2, vs1) =>
      self.execute_vector_compare_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLeu,
        current_pc,
        next_pc,
        raw,
      )
    VmsleuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLeu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsleuVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLeu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsleVv(vd, vs2, vs1) =>
      self.execute_vector_compare_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLe,
        current_pc,
        next_pc,
        raw,
      )
    VmsleVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLe,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsleVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpLe,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsgtuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpGtu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsgtuVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpGtu,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsgtVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpGt,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmsgtVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_compare_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        mask_bits,
        use_mask,
        VectorCmpGt,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmandMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskAnd,
        current_pc,
        next_pc,
        raw,
      )
    VmnandMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskNand,
        current_pc,
        next_pc,
        raw,
      )
    VmandnMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskAndNot,
        current_pc,
        next_pc,
        raw,
      )
    VmxorMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskXor,
        current_pc,
        next_pc,
        raw,
      )
    VmorMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskOr,
        current_pc,
        next_pc,
        raw,
      )
    VmnorMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskNor,
        current_pc,
        next_pc,
        raw,
      )
    VmornMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskOrNot,
        current_pc,
        next_pc,
        raw,
      )
    VmxnorMm(vd, vs2, vs1) =>
      self.execute_vector_mask_logical(
        vd,
        vs2,
        vs1,
        config,
        VectorMaskXnor,
        current_pc,
        next_pc,
        raw,
      )
    VcpopM(rd, vs2) =>
      self.execute_vector_mask_count(
        rd, vs2, active_elems, mask_bits, use_mask, next_pc,
      )
    VfirstM(rd, vs2) =>
      self.execute_vector_mask_first(
        rd, vs2, active_elems, mask_bits, use_mask, next_pc,
      )
    VmsbfM(vd, vs2) =>
      self.execute_vector_mask_prefix(
        vd,
        vs2,
        active_elems,
        mask_bits,
        use_mask,
        VectorMaskSetBeforeFirst,
        current_pc,
        next_pc,
        raw,
      )
    VmsofM(vd, vs2) =>
      self.execute_vector_mask_prefix(
        vd,
        vs2,
        active_elems,
        mask_bits,
        use_mask,
        VectorMaskSetOnlyFirst,
        current_pc,
        next_pc,
        raw,
      )
    VmsifM(vd, vs2) =>
      self.execute_vector_mask_prefix(
        vd,
        vs2,
        active_elems,
        mask_bits,
        use_mask,
        VectorMaskSetIncludingFirst,
        current_pc,
        next_pc,
        raw,
      )
    ViotaM(vd, vs2) =>
      self.execute_vector_iota(
        vd, vs2, config, active_elems, mask_bits, use_mask, current_pc, next_pc,
        raw,
      )
    VidV(vd) =>
      self.execute_vector_index(
        vd, config, active_elems, mask_bits, use_mask, current_pc, next_pc, raw,
      )
    VcompressVm(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VrgatherVv(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VrgatherVx(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VrgatherVi(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VslideupVx(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VslideupVi(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VslidedownVx(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VslidedownVi(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    Vslide1upVx(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    Vslide1downVx(_, _, _) =>
      abort("permutation instruction handled before arithmetic dispatch")
    VmvNrR(_, _, _) =>
      abort("whole-register move handled before element config")
    VsllVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSll,
        current_pc,
        next_pc,
        raw,
      )
    VsllVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1)
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSll,
        current_pc,
        next_pc,
        raw,
      )
    }
    VsllVi(vd, vs2, imm) => {
      let scalar = imm.reinterpret_as_uint().to_uint64()
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSll,
        current_pc,
        next_pc,
        raw,
      )
    }
    VsrlVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSrl,
        current_pc,
        next_pc,
        raw,
      )
    VsrlVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1)
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSrl,
        current_pc,
        next_pc,
        raw,
      )
    }
    VsrlVi(vd, vs2, imm) => {
      let scalar = imm.reinterpret_as_uint().to_uint64()
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSrl,
        current_pc,
        next_pc,
        raw,
      )
    }
    VsraVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSra,
        current_pc,
        next_pc,
        raw,
      )
    VsraVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1)
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSra,
        current_pc,
        next_pc,
        raw,
      )
    }
    VsraVi(vd, vs2, imm) => {
      let scalar = imm.reinterpret_as_uint().to_uint64()
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinSra,
        current_pc,
        next_pc,
        raw,
      )
    }
    VandVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinAnd,
        current_pc,
        next_pc,
        raw,
      )
    VandVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinAnd,
        current_pc,
        next_pc,
        raw,
      )
    }
    VandVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinAnd,
        current_pc,
        next_pc,
        raw,
      )
    }
    VorVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinOr,
        current_pc,
        next_pc,
        raw,
      )
    VorVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinOr,
        current_pc,
        next_pc,
        raw,
      )
    }
    VorVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinOr,
        current_pc,
        next_pc,
        raw,
      )
    }
    VxorVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinXor,
        current_pc,
        next_pc,
        raw,
      )
    VxorVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinXor,
        current_pc,
        next_pc,
        raw,
      )
    }
    VxorVi(vd, vs2, imm) => {
      let scalar = int_to_uint64_bits(imm) & sew_mask
      self.execute_vector_binary_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinXor,
        current_pc,
        next_pc,
        raw,
      )
    }
    _ => abort("unexpected vector first-slice dispatch")
  }
}
