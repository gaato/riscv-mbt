// Widening RVV integer arithmetic. These helpers keep the 2*SEW/2*LMUL
// legality rules out of the single-width arithmetic dispatcher.

///|
priv enum VectorWideningOp {
  VectorWideAddUnsigned
  VectorWideAddSigned
  VectorWideSubUnsigned
  VectorWideSubSigned
}

///|
fn vector_widening_source_value(
  value : UInt64,
  source_sew_bits : Int,
  signed : Bool,
) -> UInt64 {
  if signed {
    vector_signed_lane(value, source_sew_bits).reinterpret_as_uint64()
  } else {
    value & vector_elem_mask(source_sew_bits)
  }
}

///|
fn vector_apply_widening(
  lhs : UInt64,
  rhs : UInt64,
  op : VectorWideningOp,
  source_sew_bits : Int,
) -> UInt64 {
  let signed = match op {
    VectorWideAddUnsigned | VectorWideSubUnsigned => false
    VectorWideAddSigned | VectorWideSubSigned => true
  }
  let lhs_wide = vector_widening_source_value(lhs, source_sew_bits, signed)
  let rhs_wide = vector_widening_source_value(rhs, source_sew_bits, signed)
  match op {
    VectorWideAddUnsigned | VectorWideAddSigned => lhs_wide + rhs_wide
    VectorWideSubUnsigned | VectorWideSubSigned => lhs_wide - rhs_wide
  }
}

///|
fn vector_group_register_end(base_vreg : Int, lmul_log2 : Int) -> Int {
  base_vreg + vector_lmul_registers(lmul_log2)
}

///|
fn vector_groups_overlap(
  left_base : Int,
  left_lmul_log2 : Int,
  right_base : Int,
  right_lmul_log2 : Int,
) -> Bool {
  let left_end = vector_group_register_end(left_base, left_lmul_log2)
  let right_end = vector_group_register_end(right_base, right_lmul_log2)
  left_base < right_end && right_base < left_end
}

///|
fn vector_widening_overlap_allowed(
  dest_base : Int,
  dest_lmul_log2 : Int,
  source_base : Int,
  source_lmul_log2 : Int,
) -> Bool {
  if !vector_groups_overlap(
      dest_base, dest_lmul_log2, source_base, source_lmul_log2,
    ) {
    return true
  }
  if source_lmul_log2 < 0 {
    return false
  }
  let source_regs = vector_lmul_registers(source_lmul_log2)
  let dest_end = vector_group_register_end(dest_base, dest_lmul_log2)
  source_base >= dest_end - source_regs &&
  vector_group_register_end(source_base, source_lmul_log2) <= dest_end
}

///|
fn vector_widening_groups_legal(
  vd : Int,
  vs2 : Int,
  vs1 : Int?,
  source_lmul_log2 : Int,
  dest_lmul_log2 : Int,
  use_mask : Bool,
) -> Bool {
  if !vector_group_aligned(vd, dest_lmul_log2) ||
    !vector_group_aligned(vs2, source_lmul_log2) {
    return false
  }
  if use_mask && vector_group_contains_vreg(vd, dest_lmul_log2, 0) {
    return false
  }
  if !vector_widening_overlap_allowed(vd, dest_lmul_log2, vs2, source_lmul_log2) {
    return false
  }
  match vs1 {
    Some(vs1_value) =>
      vector_group_aligned(vs1_value, source_lmul_log2) &&
      vector_widening_overlap_allowed(
        vd, dest_lmul_log2, vs1_value, source_lmul_log2,
      )
    None => true
  }
}

///|
fn Runner::execute_vector_widening_vv(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  op : VectorWideningOp,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let dest_sew_bits = config.sew_bits * 2
  let dest_lmul_log2 = config.lmul_log2 + 1
  if dest_sew_bits > 64 ||
    dest_lmul_log2 > 3 ||
    !vector_widening_groups_legal(
      vd,
      vs2,
      Some(vs1),
      config.lmul_log2,
      dest_lmul_log2,
      use_mask,
    ) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  let dest_mask = vector_elem_mask(dest_sew_bits)
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let lhs = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      let rhs = self.read_vreg_group_elem(vs1, elem, config.sew_bits)
      let result = vector_apply_widening(lhs, rhs, op, config.sew_bits)
      self.write_vreg_group_elem(vd, elem, dest_sew_bits, result & dest_mask)
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_widening_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  op : VectorWideningOp,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let dest_sew_bits = config.sew_bits * 2
  let dest_lmul_log2 = config.lmul_log2 + 1
  if dest_sew_bits > 64 ||
    dest_lmul_log2 > 3 ||
    !vector_widening_groups_legal(
      vd,
      vs2,
      None,
      config.lmul_log2,
      dest_lmul_log2,
      use_mask,
    ) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  let source_mask = vector_elem_mask(config.sew_bits)
  let dest_mask = vector_elem_mask(dest_sew_bits)
  let scalar_lane = scalar & source_mask
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let lhs = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      let result = vector_apply_widening(lhs, scalar_lane, op, config.sew_bits)
      self.write_vreg_group_elem(vd, elem, dest_sew_bits, result & dest_mask)
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_widening_instruction(
  self : Runner,
  instruction : Instruction,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    VwadduVv(vd, vs2, vs1) =>
      self.execute_vector_widening_vv(
        vd,
        vs2,
        vs1,
        VectorWideAddUnsigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwadduVx(vd, vs2, rs1) =>
      self.execute_vector_widening_scalar(
        vd,
        vs2,
        self.cpu.read_reg(rs1),
        VectorWideAddUnsigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwaddVv(vd, vs2, vs1) =>
      self.execute_vector_widening_vv(
        vd,
        vs2,
        vs1,
        VectorWideAddSigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwaddVx(vd, vs2, rs1) =>
      self.execute_vector_widening_scalar(
        vd,
        vs2,
        self.cpu.read_reg(rs1),
        VectorWideAddSigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwsubuVv(vd, vs2, vs1) =>
      self.execute_vector_widening_vv(
        vd,
        vs2,
        vs1,
        VectorWideSubUnsigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwsubuVx(vd, vs2, rs1) =>
      self.execute_vector_widening_scalar(
        vd,
        vs2,
        self.cpu.read_reg(rs1),
        VectorWideSubUnsigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwsubVv(vd, vs2, vs1) =>
      self.execute_vector_widening_vv(
        vd,
        vs2,
        vs1,
        VectorWideSubSigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    VwsubVx(vd, vs2, rs1) =>
      self.execute_vector_widening_scalar(
        vd,
        vs2,
        self.cpu.read_reg(rs1),
        VectorWideSubSigned,
        config,
        active_elems,
        mask_bits,
        use_mask,
        current_pc,
        next_pc,
        raw,
      )
    _ => self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
}
