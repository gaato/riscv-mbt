// Scalar F/D execution helpers. The implementation follows the constrained
// host-IEEE contract documented for this repo and keeps NaN-boxing behavior
// visible in tests.

///|
fn Runner::fp_has_d(self : Runner) -> Bool {
  (self.config.extensions & MISA_EXT_D) != 0U.to_uint64()
}

///|
fn Runner::write_freg_single_bits(
  self : Runner,
  rd : Int,
  value : UInt,
) -> Unit {
  let stored = if self.fp_has_d() {
    (0xffffffffU.to_uint64() << 32) | value.to_uint64()
  } else {
    value.to_uint64()
  }
  self.cpu.write_freg(rd, stored)
}

///|
fn Runner::read_freg_single_transfer_bits(self : Runner, rs : Int) -> UInt {
  low32(self.cpu.read_freg(rs))
}

///|
fn Runner::read_freg_single_value_bits(self : Runner, rs : Int) -> UInt {
  let slot = self.cpu.read_freg(rs)
  if self.fp_has_d() && slot >> 32 != 0xffffffffU.to_uint64() {
    f32_canonical_nan_bits()
  } else {
    low32(slot)
  }
}

///|
fn Runner::write_freg_double_bits(
  self : Runner,
  rd : Int,
  value : UInt64,
) -> Unit {
  self.cpu.write_freg(rd, value)
}

///|
fn Runner::read_freg_double_bits(self : Runner, rs : Int) -> UInt64 {
  self.cpu.read_freg(rs)
}

///|
fn f32_is_nan_bits(bits : UInt) -> Bool {
  (bits & 0x7f800000U) == 0x7f800000U && (bits & 0x007fffffU) != 0U
}

///|
fn f32_is_zero_bits(bits : UInt) -> Bool {
  (bits & 0x7fffffffU) == 0U
}

///|
fn f32_sign_bit(bits : UInt) -> Bool {
  (bits & 0x80000000U) != 0U
}

///|
fn f32_canonical_nan_bits() -> UInt {
  0x7fc00000U
}

///|
fn f32_from_bits(bits : UInt) -> Float {
  Float::reinterpret_from_uint(bits)
}

///|
fn f32_bits_from_host(value : Float) -> UInt {
  let bits = Float::reinterpret_as_uint(value)
  if f32_is_nan_bits(bits) {
    f32_canonical_nan_bits()
  } else {
    bits
  }
}

///|
fn f64_is_nan_bits(bits : UInt64) -> Bool {
  let exponent_mask = 0x7ffU.to_uint64() << 52
  let fraction_mask = (1U.to_uint64() << 52) - 1U.to_uint64()
  (bits & exponent_mask) == exponent_mask &&
  (bits & fraction_mask) != 0U.to_uint64()
}

///|
fn f64_is_zero_bits(bits : UInt64) -> Bool {
  let magnitude_mask = (1U.to_uint64() << 63) - 1U.to_uint64()
  (bits & magnitude_mask) == 0U.to_uint64()
}

///|
fn f64_sign_bit(bits : UInt64) -> Bool {
  let sign_mask = 1U.to_uint64() << 63
  (bits & sign_mask) != 0U.to_uint64()
}

///|
fn f64_canonical_nan_bits() -> UInt64 {
  (0x7ffU.to_uint64() << 52) | (1U.to_uint64() << 51)
}

///|
fn f64_from_bits(bits : UInt64) -> Double {
  bits.reinterpret_as_double()
}

///|
fn f64_bits_from_host(value : Double) -> UInt64 {
  let bits = value.reinterpret_as_uint64()
  if f64_is_nan_bits(bits) {
    f64_canonical_nan_bits()
  } else {
    bits
  }
}

///|
fn f32_min_bits(lhs : UInt, rhs : UInt) -> UInt {
  if f32_is_nan_bits(lhs) && f32_is_nan_bits(rhs) {
    f32_canonical_nan_bits()
  } else if f32_is_nan_bits(lhs) {
    rhs
  } else if f32_is_nan_bits(rhs) {
    lhs
  } else if f32_is_zero_bits(lhs) && f32_is_zero_bits(rhs) {
    if f32_sign_bit(lhs) || f32_sign_bit(rhs) {
      0x80000000U
    } else {
      0U
    }
  } else if f32_from_bits(lhs) < f32_from_bits(rhs) {
    lhs
  } else {
    rhs
  }
}

///|
fn f64_min_bits(lhs : UInt64, rhs : UInt64) -> UInt64 {
  if f64_is_nan_bits(lhs) && f64_is_nan_bits(rhs) {
    f64_canonical_nan_bits()
  } else if f64_is_nan_bits(lhs) {
    rhs
  } else if f64_is_nan_bits(rhs) {
    lhs
  } else if f64_is_zero_bits(lhs) && f64_is_zero_bits(rhs) {
    if f64_sign_bit(lhs) || f64_sign_bit(rhs) {
      1U.to_uint64() << 63
    } else {
      0U.to_uint64()
    }
  } else if f64_from_bits(lhs) < f64_from_bits(rhs) {
    lhs
  } else {
    rhs
  }
}

///|
fn f32_max_bits(lhs : UInt, rhs : UInt) -> UInt {
  if f32_is_nan_bits(lhs) && f32_is_nan_bits(rhs) {
    f32_canonical_nan_bits()
  } else if f32_is_nan_bits(lhs) {
    rhs
  } else if f32_is_nan_bits(rhs) {
    lhs
  } else if f32_is_zero_bits(lhs) && f32_is_zero_bits(rhs) {
    if f32_sign_bit(lhs) && !f32_sign_bit(rhs) {
      rhs
    } else {
      lhs
    }
  } else if f32_from_bits(lhs) > f32_from_bits(rhs) {
    lhs
  } else {
    rhs
  }
}

///|
fn f64_max_bits(lhs : UInt64, rhs : UInt64) -> UInt64 {
  if f64_is_nan_bits(lhs) && f64_is_nan_bits(rhs) {
    f64_canonical_nan_bits()
  } else if f64_is_nan_bits(lhs) {
    rhs
  } else if f64_is_nan_bits(rhs) {
    lhs
  } else if f64_is_zero_bits(lhs) && f64_is_zero_bits(rhs) {
    if f64_sign_bit(lhs) && !f64_sign_bit(rhs) {
      rhs
    } else {
      lhs
    }
  } else if f64_from_bits(lhs) > f64_from_bits(rhs) {
    lhs
  } else {
    rhs
  }
}

///|
fn Runner::read_fcsr(self : Runner) -> UInt64 {
  self.cpu.read_csr(CSR_FCSR) & FCSR_VISIBLE_MASK
}

///|
fn Runner::write_fcsr(self : Runner, value : UInt64) -> Unit {
  self.cpu.write_csr(CSR_FCSR, value & FCSR_VISIBLE_MASK)
}

///|
fn Runner::read_frm(self : Runner) -> UInt {
  ((self.read_fcsr() & FCSR_FRM_MASK) >> FCSR_FRM_SHIFT).to_uint()
}

///|
fn Runner::fp_rounding_mode_supported(self : Runner, rm : UInt) -> Bool {
  if rm == 0U {
    true
  } else if rm == 7U {
    self.read_frm() == 0U
  } else {
    false
  }
}

///|
fn Runner::execute_fp_load_store(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Flw(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 4, next_pc, fn(pa) {
        self.write_freg_single_bits(rd, self.phy_load_u32(pa).to_uint())
      })
    Fld(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 8, next_pc, fn(pa) {
        self.write_freg_double_bits(rd, self.phy_load_u64(pa))
      })
    Fsw(rs1, rs2, imm) =>
      self.store_and_commit(rs1, imm, 4, next_pc, fn(pa) {
        self.phy_store_u32(
          pa,
          self.read_freg_single_transfer_bits(rs2).to_uint64(),
        )
      })
    Fsd(rs1, rs2, imm) =>
      self.store_and_commit(rs1, imm, 8, next_pc, fn(pa) {
        self.phy_store_u64(pa, self.read_freg_double_bits(rs2))
      })
    _ => abort("unexpected fp load/store dispatch")
  }
}

///|
fn Runner::execute_fp(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    FmvXW(rd, rs1) => {
      self.write_xlen_reg(
        rd,
        sign_extend_64(self.read_freg_single_transfer_bits(rs1).to_uint64(), 32),
      )
      self.cpu.pc = next_pc
      Running
    }
    FmvWX(rd, rs1) => {
      self.write_freg_single_bits(rd, low32(self.cpu.read_reg(rs1)))
      self.cpu.pc = next_pc
      Running
    }
    FmvXD(rd, rs1) => {
      self.write_xlen_reg(rd, self.read_freg_double_bits(rs1))
      self.cpu.pc = next_pc
      Running
    }
    FmvDX(rd, rs1) => {
      self.write_freg_double_bits(rd, self.cpu.read_reg(rs1))
      self.cpu.pc = next_pc
      Running
    }
    FAddS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(
        f32_from_bits(self.read_freg_single_value_bits(rs1)) +
        f32_from_bits(self.read_freg_single_value_bits(rs2)),
      )
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSubS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(
        f32_from_bits(self.read_freg_single_value_bits(rs1)) -
        f32_from_bits(self.read_freg_single_value_bits(rs2)),
      )
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMulS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(
        f32_from_bits(self.read_freg_single_value_bits(rs1)) *
        f32_from_bits(self.read_freg_single_value_bits(rs2)),
      )
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FDivS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(
        f32_from_bits(self.read_freg_single_value_bits(rs1)) /
        f32_from_bits(self.read_freg_single_value_bits(rs2)),
      )
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSqrtS(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(
        f32_from_bits(self.read_freg_single_value_bits(rs1)).sqrt(),
      )
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMinS(rd, rs1, rs2) => {
      self.write_freg_single_bits(
        rd,
        f32_min_bits(
          self.read_freg_single_value_bits(rs1),
          self.read_freg_single_value_bits(rs2),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    FMaxS(rd, rs1, rs2) => {
      self.write_freg_single_bits(
        rd,
        f32_max_bits(
          self.read_freg_single_value_bits(rs1),
          self.read_freg_single_value_bits(rs2),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    FAddD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(
        f64_from_bits(self.read_freg_double_bits(rs1)) +
        f64_from_bits(self.read_freg_double_bits(rs2)),
      )
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSubD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(
        f64_from_bits(self.read_freg_double_bits(rs1)) -
        f64_from_bits(self.read_freg_double_bits(rs2)),
      )
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMulD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(
        f64_from_bits(self.read_freg_double_bits(rs1)) *
        f64_from_bits(self.read_freg_double_bits(rs2)),
      )
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FDivD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(
        f64_from_bits(self.read_freg_double_bits(rs1)) /
        f64_from_bits(self.read_freg_double_bits(rs2)),
      )
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSqrtD(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(
        f64_from_bits(self.read_freg_double_bits(rs1)).sqrt(),
      )
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMinD(rd, rs1, rs2) => {
      self.write_freg_double_bits(
        rd,
        f64_min_bits(
          self.read_freg_double_bits(rs1),
          self.read_freg_double_bits(rs2),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    FMaxD(rd, rs1, rs2) => {
      self.write_freg_double_bits(
        rd,
        f64_max_bits(
          self.read_freg_double_bits(rs1),
          self.read_freg_double_bits(rs2),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSD(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = Float::from_double(
        f64_from_bits(self.read_freg_double_bits(rs1)),
      )
      self.write_freg_single_bits(rd, f32_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FCvtDS(rd, rs1, _) => {
      let result = f32_from_bits(self.read_freg_single_value_bits(rs1)).to_double()
      self.write_freg_double_bits(rd, f64_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected fp dispatch")
  }
}
