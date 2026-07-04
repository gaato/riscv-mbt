///|
priv enum VectorMultiplyHighOp {
  VectorMulHighUnsigned
  VectorMulHighSigned
  VectorMulHighSignedUnsigned
}

///|
fn vector_unsigned_mul_high_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  // MoonBit exposes 64-bit wrapping multiplication, but not the upper half of
  // a 128-bit product. Split both operands into 32-bit limbs so every partial
  // product still fits in UInt64, then carry the middle terms into the high word.
  let limb_mask = 0xffffffffU.to_uint64()
  let lhs_lo = lhs & limb_mask
  let lhs_hi = lhs >> 32
  let rhs_lo = rhs & limb_mask
  let rhs_hi = rhs >> 32
  let p0 = lhs_lo * rhs_lo
  let p1 = lhs_lo * rhs_hi
  let p2 = lhs_hi * rhs_lo
  let p3 = lhs_hi * rhs_hi
  let middle = (p0 >> 32) + (p1 & limb_mask) + (p2 & limb_mask)
  p3 + (p1 >> 32) + (p2 >> 32) + (middle >> 32)
}

///|
fn vector_signed_mul_high_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let sign_bit = 1U.to_uint64() << 63
  let mut high = vector_unsigned_mul_high_64(lhs, rhs)
  // For two's-complement signed multiply, start from the unsigned high word
  // and subtract the opposite operand for each negative signed input.
  if (lhs & sign_bit) != 0U.to_uint64() {
    high = high - rhs
  }
  if (rhs & sign_bit) != 0U.to_uint64() {
    high = high - lhs
  }
  high
}

///|
fn vector_signed_unsigned_mul_high_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let sign_bit = 1U.to_uint64() << 63
  let mut high = vector_unsigned_mul_high_64(lhs, rhs)
  // `vmulhsu` treats vs2 as signed and vs1/rs1 as unsigned, so only the first
  // operand contributes the signed correction.
  if (lhs & sign_bit) != 0U.to_uint64() {
    high = high - rhs
  }
  high
}

///|
fn vector_multiply_high_lane(
  lhs : UInt64,
  rhs : UInt64,
  op : VectorMultiplyHighOp,
  sew_bits : Int,
) -> UInt64 {
  if sew_bits == 64 {
    match op {
      VectorMulHighUnsigned => vector_unsigned_mul_high_64(lhs, rhs)
      VectorMulHighSigned => vector_signed_mul_high_64(lhs, rhs)
      VectorMulHighSignedUnsigned =>
        vector_signed_unsigned_mul_high_64(lhs, rhs)
    }
  } else {
    match op {
      VectorMulHighUnsigned => (lhs * rhs) >> sew_bits
      VectorMulHighSigned => {
        let product = vector_signed_lane(lhs, sew_bits) *
          vector_signed_lane(rhs, sew_bits)
        (product >> sew_bits).reinterpret_as_uint64()
      }
      VectorMulHighSignedUnsigned => {
        let product = vector_signed_lane(lhs, sew_bits) *
          rhs.reinterpret_as_int64()
        (product >> sew_bits).reinterpret_as_uint64()
      }
    }
  }
}

///|
fn Runner::execute_vector_multiply_high_vv(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorMultiplyHighOp,
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
        vector_multiply_high_lane(lhs, rhs, op, config.sew_bits) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_multiply_high_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  op : VectorMultiplyHighOp,
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
        vector_multiply_high_lane(lhs, scalar, op, config.sew_bits) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_multiply_instruction(
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
    VmulVv(vd, vs2, vs1) =>
      self.execute_vector_binary_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorBinMul,
        current_pc,
        next_pc,
        raw,
      )
    VmulVx(vd, vs2, rs1) => {
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
        VectorBinMul,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmulhuVv(vd, vs2, vs1) =>
      self.execute_vector_multiply_high_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorMulHighUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    VmulhuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_multiply_high_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorMulHighUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmulhVv(vd, vs2, vs1) =>
      self.execute_vector_multiply_high_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorMulHighSigned,
        current_pc,
        next_pc,
        raw,
      )
    VmulhVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_multiply_high_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorMulHighSigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    VmulhsuVv(vd, vs2, vs1) =>
      self.execute_vector_multiply_high_vv(
        vd,
        vs2,
        vs1,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorMulHighSignedUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    VmulhsuVx(vd, vs2, rs1) => {
      let scalar = self.cpu.read_reg(rs1) & sew_mask
      self.execute_vector_multiply_high_scalar(
        vd,
        vs2,
        scalar,
        config,
        active_elems,
        sew_mask,
        mask_bits,
        use_mask,
        VectorMulHighSignedUnsigned,
        current_pc,
        next_pc,
        raw,
      )
    }
    _ => self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
}
