// RVV integer divide and remainder helpers. These are separated from the main
// vector file because divide has RISC-V-specific zero/overflow corner cases
// that are easy to accidentally "simplify" into host-language behavior.

///|
priv enum VectorDivideOp {
  VectorDivUnsigned
  VectorDivSigned
  VectorRemUnsigned
  VectorRemSigned
}

///|
fn vector_signed_division_overflows(
  lhs : UInt64,
  rhs : UInt64,
  sew_bits : Int,
) -> Bool {
  let sign_bit = 1U.to_uint64() << (sew_bits - 1)
  lhs == sign_bit && rhs == vector_elem_mask(sew_bits)
}

///|
fn vector_apply_divide(
  lhs : UInt64,
  rhs : UInt64,
  op : VectorDivideOp,
  sew_bits : Int,
  sew_mask : UInt64,
) -> UInt64 {
  match op {
    VectorDivUnsigned =>
      if rhs == 0U.to_uint64() {
        sew_mask
      } else {
        lhs / rhs
      }
    VectorRemUnsigned => if rhs == 0U.to_uint64() { lhs } else { lhs % rhs }
    VectorDivSigned =>
      if rhs == 0U.to_uint64() {
        // RISC-V integer division by zero returns an all-ones quotient.
        sew_mask
      } else if vector_signed_division_overflows(lhs, rhs, sew_bits) {
        // The only signed overflow is INT_MIN / -1. The quotient is the
        // original dividend and the matching remainder is zero.
        lhs
      } else {
        let quotient = vector_signed_lane(lhs, sew_bits) /
          vector_signed_lane(rhs, sew_bits)
        quotient.reinterpret_as_uint64()
      }
    VectorRemSigned =>
      if rhs == 0U.to_uint64() {
        // RISC-V keeps the dividend as the remainder when dividing by zero.
        lhs
      } else if vector_signed_division_overflows(lhs, rhs, sew_bits) {
        0U.to_uint64()
      } else {
        let remainder = vector_signed_lane(lhs, sew_bits) %
          vector_signed_lane(rhs, sew_bits)
        remainder.reinterpret_as_uint64()
      }
  }
}

///|
fn Runner::execute_vector_divide_vv(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorDivideOp,
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
        vector_apply_divide(lhs, rhs, op, config.sew_bits, sew_mask) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_divide_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorDivideOp,
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
        vector_apply_divide(lhs, scalar, op, config.sew_bits, sew_mask) &
        sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_divide_instruction(
  self : Runner,
  instruction : Instruction,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    VdivuVv(vd, vs2, vs1) =>
      self.execute_vector_divide_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorDivUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    VdivuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_divide_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorDivUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    VdivVv(vd, vs2, vs1) =>
      self.execute_vector_divide_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorDivSigned,
        current_pc,
        next_pc,
        raw,
      )
    VdivVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_divide_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorDivSigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    VremuVv(vd, vs2, vs1) =>
      self.execute_vector_divide_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorRemUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    VremuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_divide_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorRemUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    VremVv(vd, vs2, vs1) =>
      self.execute_vector_divide_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorRemSigned,
        current_pc,
        next_pc,
        raw,
      )
    VremVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_divide_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorRemSigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    _ => self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
}
