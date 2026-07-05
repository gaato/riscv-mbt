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
  // When D is present, single-precision values must be NaN-boxed in the 64-bit
  // FP register file. Transfer instructions still use the raw low 32 bits.
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
  // Arithmetic reads validate NaN boxing. A malformed boxed value becomes the
  // canonical NaN, which is the Linux-practical behavior pinned by tests.
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
  // Host Float operations are used for the practical Linux path, but NaN
  // payload/sign details are normalized so tests see a stable canonical value.
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
  // Same policy as single precision: use the host for arithmetic, then
  // canonicalize NaN bits so behavior is deterministic across hosts.
  let bits = value.reinterpret_as_uint64()
  if f64_is_nan_bits(bits) {
    f64_canonical_nan_bits()
  } else {
    bits
  }
}

///|
fn f32_class_mask(bits : UInt) -> UInt64 {
  // FCLASS returns exactly one class bit and never updates fflags.
  let sign = (bits & 0x80000000U) != 0U
  let exponent = bits & 0x7f800000U
  let fraction = bits & 0x007fffffU
  if exponent == 0x7f800000U {
    if fraction == 0U {
      if sign {
        0x001U.to_uint64()
      } else {
        0x080U.to_uint64()
      }
    } else if (fraction & 0x00400000U) == 0U {
      0x100U.to_uint64()
    } else {
      0x200U.to_uint64()
    }
  } else if exponent == 0U {
    if fraction == 0U {
      if sign {
        0x008U.to_uint64()
      } else {
        0x010U.to_uint64()
      }
    } else if sign {
      0x004U.to_uint64()
    } else {
      0x020U.to_uint64()
    }
  } else if sign {
    0x002U.to_uint64()
  } else {
    0x040U.to_uint64()
  }
}

///|
fn f64_class_mask(bits : UInt64) -> UInt64 {
  let sign = (bits & (1U.to_uint64() << 63)) != 0U.to_uint64()
  let exponent = bits & (0x7ffU.to_uint64() << 52)
  let fraction = bits & ((1U.to_uint64() << 52) - 1U.to_uint64())
  if exponent == 0x7ffU.to_uint64() << 52 {
    if fraction == 0U.to_uint64() {
      if sign {
        0x001U.to_uint64()
      } else {
        0x080U.to_uint64()
      }
    } else if (fraction & (1U.to_uint64() << 51)) == 0U.to_uint64() {
      0x100U.to_uint64()
    } else {
      0x200U.to_uint64()
    }
  } else if exponent == 0U.to_uint64() {
    if fraction == 0U.to_uint64() {
      if sign {
        0x008U.to_uint64()
      } else {
        0x010U.to_uint64()
      }
    } else if sign {
      0x004U.to_uint64()
    } else {
      0x020U.to_uint64()
    }
  } else if sign {
    0x002U.to_uint64()
  } else {
    0x040U.to_uint64()
  }
}

///|
fn f32_min_bits(lhs : UInt, rhs : UInt) -> UInt {
  // FMIN/FMAX have special zero and NaN rules that ordinary host min/max do
  // not express. Keep the bit-level cases explicit instead of delegating.
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
  // Current practical FP scope: arithmetic and int-to-float conversions support
  // RNE only. Other modes trap instead of silently producing host-default
  // results that look architectural but are not.
  if rm == 0U {
    true
  } else if rm == 7U {
    self.read_frm() == 0U
  } else {
    false
  }
}

///|
fn Runner::fp_effective_rounding_mode(self : Runner, rm : UInt) -> UInt? {
  if rm <= 4U {
    Some(rm)
  } else if rm == 7U {
    let frm = self.read_frm()
    if frm <= 4U {
      Some(frm)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn fp_integer_is_even(value : Double) -> Bool {
  value.to_int64() % 2L == 0L
}

///|
fn fp_round_to_integer(value : Double, mode : UInt) -> Double {
  match mode {
    0U => {
      let down = value.floor()
      let up = value.ceil()
      let down_delta = value - down
      let up_delta = up - value
      if down_delta < up_delta {
        down
      } else if up_delta < down_delta {
        up
      } else if fp_integer_is_even(down) {
        down
      } else {
        up
      }
    }
    1U => value.trunc()
    2U => value.floor()
    3U => value.ceil()
    4U => if value < 0.0 { (value - 0.5).ceil() } else { (value + 0.5).floor() }
    _ => value.trunc()
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
    FMAddS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_from_bits(self.read_freg_single_value_bits(rs1)) *
        f32_from_bits(self.read_freg_single_value_bits(rs2)) +
        f32_from_bits(self.read_freg_single_value_bits(rs3))
      self.write_freg_single_bits(rd, f32_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FMSubS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_from_bits(self.read_freg_single_value_bits(rs1)) *
        f32_from_bits(self.read_freg_single_value_bits(rs2)) -
        f32_from_bits(self.read_freg_single_value_bits(rs3))
      self.write_freg_single_bits(rd, f32_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FNMSubS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let product = f32_from_bits(self.read_freg_single_value_bits(rs1)) *
        f32_from_bits(self.read_freg_single_value_bits(rs2))
      let addend = f32_from_bits(self.read_freg_single_value_bits(rs3))
      let result = addend - product
      self.write_freg_single_bits(rd, f32_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FNMAddS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let product = f32_from_bits(self.read_freg_single_value_bits(rs1)) *
        f32_from_bits(self.read_freg_single_value_bits(rs2))
      let addend = f32_from_bits(self.read_freg_single_value_bits(rs3))
      let result = Float::from_double(0.0) - product - addend
      self.write_freg_single_bits(rd, f32_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FMAddD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_from_bits(self.read_freg_double_bits(rs1)) *
        f64_from_bits(self.read_freg_double_bits(rs2)) +
        f64_from_bits(self.read_freg_double_bits(rs3))
      self.write_freg_double_bits(rd, f64_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FMSubD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_from_bits(self.read_freg_double_bits(rs1)) *
        f64_from_bits(self.read_freg_double_bits(rs2)) -
        f64_from_bits(self.read_freg_double_bits(rs3))
      self.write_freg_double_bits(rd, f64_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FNMSubD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = 0.0 -
        f64_from_bits(self.read_freg_double_bits(rs1)) *
        f64_from_bits(self.read_freg_double_bits(rs2)) +
        f64_from_bits(self.read_freg_double_bits(rs3))
      self.write_freg_double_bits(rd, f64_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FNMAddD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = 0.0 -
        f64_from_bits(self.read_freg_double_bits(rs1)) *
        f64_from_bits(self.read_freg_double_bits(rs2)) -
        f64_from_bits(self.read_freg_double_bits(rs3))
      self.write_freg_double_bits(rd, f64_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
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
    FSgnjS(rd, rs1, rs2) => {
      let sign_mask = 0x80000000U
      let magnitude = self.read_freg_single_transfer_bits(rs1) &
        sign_mask.lnot()
      let sign = self.read_freg_single_transfer_bits(rs2) & sign_mask
      self.write_freg_single_bits(rd, magnitude | sign)
      self.cpu.pc = next_pc
      Running
    }
    FSgnjnS(rd, rs1, rs2) => {
      let sign_mask = 0x80000000U
      let magnitude = self.read_freg_single_transfer_bits(rs1) &
        sign_mask.lnot()
      let sign = self.read_freg_single_transfer_bits(rs2).lnot() & sign_mask
      self.write_freg_single_bits(rd, magnitude | sign)
      self.cpu.pc = next_pc
      Running
    }
    FSgnjxS(rd, rs1, rs2) => {
      let sign_mask = 0x80000000U
      let lhs = self.read_freg_single_transfer_bits(rs1)
      let rhs = self.read_freg_single_transfer_bits(rs2)
      self.write_freg_single_bits(
        rd,
        (lhs & sign_mask.lnot()) | ((lhs ^ rhs) & sign_mask),
      )
      self.cpu.pc = next_pc
      Running
    }
    FLeS(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let result = if f32_is_nan_bits(lhs_bits) || f32_is_nan_bits(rhs_bits) {
        0U.to_uint64()
      } else if f32_from_bits(lhs_bits) <= f32_from_bits(rhs_bits) {
        1U.to_uint64()
      } else {
        0U.to_uint64()
      }
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FLtS(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let result = if f32_is_nan_bits(lhs_bits) || f32_is_nan_bits(rhs_bits) {
        0U.to_uint64()
      } else if f32_from_bits(lhs_bits) < f32_from_bits(rhs_bits) {
        1U.to_uint64()
      } else {
        0U.to_uint64()
      }
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FEqS(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let result = if f32_is_nan_bits(lhs_bits) || f32_is_nan_bits(rhs_bits) {
        0U.to_uint64()
      } else if f32_from_bits(lhs_bits) == f32_from_bits(rhs_bits) {
        1U.to_uint64()
      } else {
        0U.to_uint64()
      }
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FClassS(rd, rs1) => {
      self.write_xlen_reg(
        rd,
        f32_class_mask(self.read_freg_single_value_bits(rs1)),
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
    FSgnjD(rd, rs1, rs2) => {
      let sign_mask = 1U.to_uint64() << 63
      let magnitude = self.read_freg_double_bits(rs1) & sign_mask.lnot()
      let sign = self.read_freg_double_bits(rs2) & sign_mask
      self.write_freg_double_bits(rd, magnitude | sign)
      self.cpu.pc = next_pc
      Running
    }
    FSgnjnD(rd, rs1, rs2) => {
      let sign_mask = 1U.to_uint64() << 63
      let magnitude = self.read_freg_double_bits(rs1) & sign_mask.lnot()
      let sign = self.read_freg_double_bits(rs2).lnot() & sign_mask
      self.write_freg_double_bits(rd, magnitude | sign)
      self.cpu.pc = next_pc
      Running
    }
    FSgnjxD(rd, rs1, rs2) => {
      let sign_mask = 1U.to_uint64() << 63
      let lhs = self.read_freg_double_bits(rs1)
      let rhs = self.read_freg_double_bits(rs2)
      self.write_freg_double_bits(
        rd,
        (lhs & sign_mask.lnot()) | ((lhs ^ rhs) & sign_mask),
      )
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
    FLeD(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let result = if f64_is_nan_bits(lhs_bits) || f64_is_nan_bits(rhs_bits) {
        0U.to_uint64()
      } else if f64_from_bits(lhs_bits) <= f64_from_bits(rhs_bits) {
        1U.to_uint64()
      } else {
        0U.to_uint64()
      }
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FLtD(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let result = if f64_is_nan_bits(lhs_bits) || f64_is_nan_bits(rhs_bits) {
        0U.to_uint64()
      } else if f64_from_bits(lhs_bits) < f64_from_bits(rhs_bits) {
        1U.to_uint64()
      } else {
        0U.to_uint64()
      }
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FEqD(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let result = if f64_is_nan_bits(lhs_bits) || f64_is_nan_bits(rhs_bits) {
        0U.to_uint64()
      } else if f64_from_bits(lhs_bits) == f64_from_bits(rhs_bits) {
        1U.to_uint64()
      } else {
        0U.to_uint64()
      }
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FClassD(rd, rs1) => {
      self.write_xlen_reg(rd, f64_class_mask(self.read_freg_double_bits(rs1)))
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
    FCvtSW(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let signed = sign_extend_64(self.cpu.read_reg(rs1), 32).reinterpret_as_int64()
      self.write_freg_single_bits(
        rd,
        f32_bits_from_host(Float::from_double(signed.to_double())),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSWU(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let unsigned = self.cpu.read_reg(rs1) & 0xffffffffU.to_uint64()
      self.write_freg_single_bits(
        rd,
        f32_bits_from_host(Float::from_double(unsigned.to_double())),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSL(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let signed = self.cpu.read_reg(rs1).reinterpret_as_int64()
      self.write_freg_single_bits(
        rd,
        f32_bits_from_host(Float::from_double(signed.to_double())),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSLU(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.write_freg_single_bits(
        rd,
        f32_bits_from_host(
          Float::from_double(self.cpu.read_reg(rs1).to_double()),
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtDW(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let signed = sign_extend_64(self.cpu.read_reg(rs1), 32).reinterpret_as_int64()
      self.write_freg_double_bits(rd, f64_bits_from_host(signed.to_double()))
      self.cpu.pc = next_pc
      Running
    }
    FCvtDWU(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let unsigned = self.cpu.read_reg(rs1) & 0xffffffffU.to_uint64()
      self.write_freg_double_bits(
        rd,
        f64_bits_from_host(Double::convert_uint64(unsigned)),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtDL(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let signed = self.cpu.read_reg(rs1).reinterpret_as_int64()
      self.write_freg_double_bits(rd, f64_bits_from_host(signed.to_double()))
      self.cpu.pc = next_pc
      Running
    }
    FCvtDLU(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.write_freg_double_bits(
        rd,
        f64_bits_from_host(Double::convert_uint64(self.cpu.read_reg(rs1))),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtWS(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = fp_round_to_integer(
        f32_from_bits(self.read_freg_single_value_bits(rs1)).to_double(),
        mode,
      ).to_int64()
      self.write_xlen_reg(
        rd,
        sign_extend_64(result.reinterpret_as_uint64(), 32),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtWUS(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = UInt64::trunc_double(
        fp_round_to_integer(
          f32_from_bits(self.read_freg_single_value_bits(rs1)).to_double(),
          mode,
        ),
      )
      self.write_xlen_reg(rd, sign_extend_64(result, 32))
      self.cpu.pc = next_pc
      Running
    }
    FCvtLS(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = fp_round_to_integer(
        f32_from_bits(self.read_freg_single_value_bits(rs1)).to_double(),
        mode,
      ).to_int64()
      self.write_xlen_reg(rd, result.reinterpret_as_uint64())
      self.cpu.pc = next_pc
      Running
    }
    FCvtLUS(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = UInt64::trunc_double(
        fp_round_to_integer(
          f32_from_bits(self.read_freg_single_value_bits(rs1)).to_double(),
          mode,
        ),
      )
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FCvtWD(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = fp_round_to_integer(
        f64_from_bits(self.read_freg_double_bits(rs1)),
        mode,
      ).to_int64()
      self.write_xlen_reg(
        rd,
        sign_extend_64(result.reinterpret_as_uint64(), 32),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtWUD(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = UInt64::trunc_double(
        fp_round_to_integer(
          f64_from_bits(self.read_freg_double_bits(rs1)),
          mode,
        ),
      )
      self.write_xlen_reg(rd, sign_extend_64(result, 32))
      self.cpu.pc = next_pc
      Running
    }
    FCvtLD(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = fp_round_to_integer(
        f64_from_bits(self.read_freg_double_bits(rs1)),
        mode,
      ).to_int64()
      self.write_xlen_reg(rd, result.reinterpret_as_uint64())
      self.cpu.pc = next_pc
      Running
    }
    FCvtLUD(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let result = UInt64::trunc_double(
        fp_round_to_integer(
          f64_from_bits(self.read_freg_double_bits(rs1)),
          mode,
        ),
      )
      self.write_xlen_reg(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected fp dispatch")
  }
}
