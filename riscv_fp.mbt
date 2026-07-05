// Scalar F/D execution helpers. The implementation follows the constrained
// host-IEEE contract documented for this repo and keeps NaN-boxing behavior
// visible in tests.

///|
let fp_fflag_nv : UInt64 = 0x10U.to_uint64()

///|
let fp_fflag_dz : UInt64 = 0x08U.to_uint64()

///|
let fp_fflag_nx : UInt64 = 0x01U.to_uint64()

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
fn f32_is_signaling_nan_bits(bits : UInt) -> Bool {
  // IEEE single-precision NaNs use the top fraction bit as the quiet bit.
  // RISC-V comparisons and min/max only raise NV for signaling NaNs in the
  // quiet-comparison/minNumber cases, so keep the bit test explicit.
  f32_is_nan_bits(bits) && (bits & 0x00400000U) == 0U
}

///|
fn f32_is_zero_bits(bits : UInt) -> Bool {
  (bits & 0x7fffffffU) == 0U
}

///|
fn f32_is_infinite_bits(bits : UInt) -> Bool {
  (bits & 0x7fffffffU) == 0x7f800000U
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
fn f64_is_signaling_nan_bits(bits : UInt64) -> Bool {
  f64_is_nan_bits(bits) && (bits & (1U.to_uint64() << 51)) == 0U.to_uint64()
}

///|
fn f64_is_zero_bits(bits : UInt64) -> Bool {
  let magnitude_mask = (1U.to_uint64() << 63) - 1U.to_uint64()
  (bits & magnitude_mask) == 0U.to_uint64()
}

///|
fn f64_is_infinite_bits(bits : UInt64) -> Bool {
  let magnitude_mask = (1U.to_uint64() << 63) - 1U.to_uint64()
  (bits & magnitude_mask) == 0x7ffU.to_uint64() << 52
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
fn f32_finite_inexact_from_double(exact : Double, result_bits : UInt) -> Bool {
  // Single-precision operands are exactly representable as Double. For the
  // current RNE-only scope this lets us detect ordinary NX cases by comparing
  // the rounded Float result against the wider calculation used to produce it.
  !f32_is_nan_bits(result_bits) &&
  !f32_is_infinite_bits(result_bits) &&
  f32_from_bits(result_bits).to_double() != exact
}

///|
priv struct FpExactRational {
  num : BigInt
  den : BigInt
}

///|
fn fp_bigint_one() -> BigInt {
  BigInt::from_int(1)
}

///|
fn fp_bigint_pow2(shift : Int) -> BigInt {
  fp_bigint_one() << shift
}

///|
fn fp_exact_rational_from_f64_bits(bits : UInt64) -> FpExactRational? {
  // Finite IEEE values are exact signed integers scaled by a power of two. This
  // representation lets us compare the mathematical D result with the rounded
  // f64 bits and accrue NX without depending on host floating-point flags.
  if f64_is_nan_bits(bits) || f64_is_infinite_bits(bits) {
    None
  } else {
    let sign = bits >> 63 != 0U.to_uint64()
    let exponent = ((bits >> 52) & 0x7ffU.to_uint64()).to_int()
    let fraction = bits & ((1U.to_uint64() << 52) - 1U.to_uint64())
    let mantissa = if exponent == 0 {
      fraction
    } else {
      (1U.to_uint64() << 52) | fraction
    }
    if mantissa == 0U.to_uint64() {
      Some({ num: BigInt::from_int(0), den: fp_bigint_one() })
    } else {
      let exp2 = if exponent == 0 {
        1 - 1023 - 52
      } else {
        exponent - 1023 - 52
      }
      let magnitude = BigInt::from_uint64(mantissa)
      let unsigned = if exp2 >= 0 {
        { num: magnitude << exp2, den: fp_bigint_one() }
      } else {
        { num: magnitude, den: fp_bigint_pow2(0 - exp2) }
      }
      if sign {
        Some({ num: -unsigned.num, den: unsigned.den })
      } else {
        Some(unsigned)
      }
    }
  }
}

///|
fn fp_exact_rational_add(
  lhs : FpExactRational,
  rhs : FpExactRational,
) -> FpExactRational {
  { num: lhs.num * rhs.den + rhs.num * lhs.den, den: lhs.den * rhs.den }
}

///|
fn fp_exact_rational_neg(value : FpExactRational) -> FpExactRational {
  { num: -value.num, den: value.den }
}

///|
fn fp_exact_rational_sub(
  lhs : FpExactRational,
  rhs : FpExactRational,
) -> FpExactRational {
  fp_exact_rational_add(lhs, fp_exact_rational_neg(rhs))
}

///|
fn fp_exact_rational_mul(
  lhs : FpExactRational,
  rhs : FpExactRational,
) -> FpExactRational {
  { num: lhs.num * rhs.num, den: lhs.den * rhs.den }
}

///|
fn fp_exact_rational_div(
  lhs : FpExactRational,
  rhs : FpExactRational,
) -> FpExactRational? {
  if rhs.num.is_zero() {
    None
  } else if rhs.num < BigInt::from_int(0) {
    Some({ num: -lhs.num * rhs.den, den: lhs.den * -rhs.num })
  } else {
    Some({ num: lhs.num * rhs.den, den: lhs.den * rhs.num })
  }
}

///|
fn fp_exact_rational_equal(
  lhs : FpExactRational,
  rhs : FpExactRational,
) -> Bool {
  lhs.num * rhs.den == rhs.num * lhs.den
}

///|
fn f64_finite_inexact_from_rational(
  exact : FpExactRational,
  result_bits : UInt64,
) -> Bool {
  match fp_exact_rational_from_f64_bits(result_bits) {
    Some(rounded) => !fp_exact_rational_equal(exact, rounded)
    None => false
  }
}

///|
fn f64_sqrt_finite_inexact_from_result(
  operand_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(operand_bits),
      fp_exact_rational_from_f64_bits(result_bits),
    ) {
    (Some(operand), Some(result)) => {
      let squared = fp_exact_rational_mul(result, result)
      !fp_exact_rational_equal(operand, squared)
    }
    _ => false
  }
}

///|
fn f64_add_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
    ) {
    (Some(lhs), Some(rhs)) =>
      f64_finite_inexact_from_rational(
        fp_exact_rational_add(lhs, rhs),
        result_bits,
      )
    _ => false
  }
}

///|
fn f64_sub_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
    ) {
    (Some(lhs), Some(rhs)) =>
      f64_finite_inexact_from_rational(
        fp_exact_rational_sub(lhs, rhs),
        result_bits,
      )
    _ => false
  }
}

///|
fn f64_mul_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
    ) {
    (Some(lhs), Some(rhs)) =>
      f64_finite_inexact_from_rational(
        fp_exact_rational_mul(lhs, rhs),
        result_bits,
      )
    _ => false
  }
}

///|
fn f64_div_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
    ) {
    (Some(lhs), Some(rhs)) =>
      match fp_exact_rational_div(lhs, rhs) {
        Some(exact) => f64_finite_inexact_from_rational(exact, result_bits)
        None => false
      }
    _ => false
  }
}

///|
fn f64_fmadd_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  addend_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
      fp_exact_rational_from_f64_bits(addend_bits),
    ) {
    (Some(lhs), Some(rhs), Some(addend)) => {
      let product = fp_exact_rational_mul(lhs, rhs)
      f64_finite_inexact_from_rational(
        fp_exact_rational_add(product, addend),
        result_bits,
      )
    }
    _ => false
  }
}

///|
fn f64_fmsub_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  addend_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
      fp_exact_rational_from_f64_bits(addend_bits),
    ) {
    (Some(lhs), Some(rhs), Some(addend)) => {
      let product = fp_exact_rational_mul(lhs, rhs)
      f64_finite_inexact_from_rational(
        fp_exact_rational_sub(product, addend),
        result_bits,
      )
    }
    _ => false
  }
}

///|
fn f64_fnmsub_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  addend_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
      fp_exact_rational_from_f64_bits(addend_bits),
    ) {
    (Some(lhs), Some(rhs), Some(addend)) => {
      let product = fp_exact_rational_mul(lhs, rhs)
      f64_finite_inexact_from_rational(
        fp_exact_rational_sub(addend, product),
        result_bits,
      )
    }
    _ => false
  }
}

///|
fn f64_fnmadd_inexact_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  addend_bits : UInt64,
  result_bits : UInt64,
) -> Bool {
  match
    (
      fp_exact_rational_from_f64_bits(lhs_bits),
      fp_exact_rational_from_f64_bits(rhs_bits),
      fp_exact_rational_from_f64_bits(addend_bits),
    ) {
    (Some(lhs), Some(rhs), Some(addend)) => {
      let product = fp_exact_rational_mul(lhs, rhs)
      f64_finite_inexact_from_rational(
        fp_exact_rational_sub(fp_exact_rational_neg(product), addend),
        result_bits,
      )
    }
    _ => false
  }
}

///|
fn f32_mul_is_invalid_bits(lhs : UInt, rhs : UInt) -> Bool {
  (f32_is_infinite_bits(lhs) && f32_is_zero_bits(rhs)) ||
  (f32_is_zero_bits(lhs) && f32_is_infinite_bits(rhs))
}

///|
fn f64_mul_is_invalid_bits(lhs : UInt64, rhs : UInt64) -> Bool {
  (f64_is_infinite_bits(lhs) && f64_is_zero_bits(rhs)) ||
  (f64_is_zero_bits(lhs) && f64_is_infinite_bits(rhs))
}

///|
fn f32_any_signaling_nan2(lhs : UInt, rhs : UInt) -> Bool {
  f32_is_signaling_nan_bits(lhs) || f32_is_signaling_nan_bits(rhs)
}

///|
fn f64_any_signaling_nan2(lhs : UInt64, rhs : UInt64) -> Bool {
  f64_is_signaling_nan_bits(lhs) || f64_is_signaling_nan_bits(rhs)
}

///|
fn f32_any_signaling_nan3(lhs : UInt, rhs : UInt, addend : UInt) -> Bool {
  f32_is_signaling_nan_bits(lhs) ||
  f32_is_signaling_nan_bits(rhs) ||
  f32_is_signaling_nan_bits(addend)
}

///|
fn f64_any_signaling_nan3(lhs : UInt64, rhs : UInt64, addend : UInt64) -> Bool {
  f64_is_signaling_nan_bits(lhs) ||
  f64_is_signaling_nan_bits(rhs) ||
  f64_is_signaling_nan_bits(addend)
}

///|
fn f32_add_is_invalid_bits(lhs : UInt, rhs : UInt) -> Bool {
  // Adding opposite-signed infinities is invalid. FSUB reuses this helper by
  // flipping the right-hand sign bit before checking the same condition.
  f32_is_infinite_bits(lhs) &&
  f32_is_infinite_bits(rhs) &&
  f32_sign_bit(lhs) != f32_sign_bit(rhs)
}

///|
fn f64_add_is_invalid_bits(lhs : UInt64, rhs : UInt64) -> Bool {
  f64_is_infinite_bits(lhs) &&
  f64_is_infinite_bits(rhs) &&
  f64_sign_bit(lhs) != f64_sign_bit(rhs)
}

///|
fn f32_div_is_invalid_bits(lhs : UInt, rhs : UInt) -> Bool {
  (f32_is_zero_bits(lhs) && f32_is_zero_bits(rhs)) ||
  (f32_is_infinite_bits(lhs) && f32_is_infinite_bits(rhs))
}

///|
fn f64_div_is_invalid_bits(lhs : UInt64, rhs : UInt64) -> Bool {
  (f64_is_zero_bits(lhs) && f64_is_zero_bits(rhs)) ||
  (f64_is_infinite_bits(lhs) && f64_is_infinite_bits(rhs))
}

///|
fn f32_div_by_zero_bits(lhs : UInt, rhs : UInt) -> Bool {
  // DZ is for a finite nonzero dividend divided by zero. Zero-over-zero is NV,
  // and NaN or infinity operands are handled by the invalid/NaN paths.
  f32_is_zero_bits(rhs) &&
  !f32_is_zero_bits(lhs) &&
  !f32_is_nan_bits(lhs) &&
  !f32_is_infinite_bits(lhs)
}

///|
fn f64_div_by_zero_bits(lhs : UInt64, rhs : UInt64) -> Bool {
  f64_is_zero_bits(rhs) &&
  !f64_is_zero_bits(lhs) &&
  !f64_is_nan_bits(lhs) &&
  !f64_is_infinite_bits(lhs)
}

///|
fn f32_sqrt_is_invalid_bits(value : UInt) -> Bool {
  f32_sign_bit(value) && !f32_is_zero_bits(value)
}

///|
fn f64_sqrt_is_invalid_bits(value : UInt64) -> Bool {
  f64_sign_bit(value) && !f64_is_zero_bits(value)
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
fn Runner::set_fflags(self : Runner, flags : UInt64) -> Unit {
  // Floating-point exception flags are accrued: instructions OR newly observed
  // conditions into fflags and software clears them explicitly through CSR
  // writes. The base F extension never traps merely because a flag is set.
  self.write_fcsr(self.read_fcsr() | (flags & FCSR_FFLAGS_MASK))
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
fn Runner::fp_rounding_mode_legal(self : Runner, rm : UInt) -> Bool {
  match self.fp_effective_rounding_mode(rm) {
    Some(_) => true
    None => false
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
fn Runner::write_fcvt_word_result(
  self : Runner,
  rd : Int,
  value : Double,
  mode : UInt,
  source_nan : Bool,
  unsigned : Bool,
) -> Unit {
  // FCVT.W[U] produces a 32-bit integer result that is sign-extended to XLEN
  // on RV64. RISC-V specifies clipped output and NV for NaN/out-of-range
  // inputs, so avoid host integer conversion until the value is known valid.
  let rounded = fp_round_to_integer(value, mode)
  let min_value = if unsigned { 0.0 } else { -2147483648.0 }
  let max_value = if unsigned { 4294967295.0 } else { 2147483647.0 }
  let invalid = source_nan || rounded < min_value || rounded > max_value
  let result_bits = if invalid {
    self.set_fflags(fp_fflag_nv)
    if source_nan || rounded > max_value {
      if unsigned {
        0xffffffffU.to_uint64()
      } else {
        0x7fffffffU.to_uint64()
      }
    } else if unsigned {
      0U.to_uint64()
    } else {
      0x80000000U.to_uint64()
    }
  } else {
    if rounded != value {
      self.set_fflags(fp_fflag_nx)
    }
    if unsigned {
      UInt64::trunc_double(rounded) & 0xffffffffU.to_uint64()
    } else {
      rounded.to_int64().reinterpret_as_uint64() & 0xffffffffU.to_uint64()
    }
  }
  self.write_xlen_reg(rd, sign_extend_64(result_bits, 32))
}

///|
fn Runner::write_fcvt_long_result(
  self : Runner,
  rd : Int,
  value : Double,
  mode : UInt,
  source_nan : Bool,
  unsigned : Bool,
) -> Unit {
  // FCVT.L[U] is RV64-only and writes the full XLEN result. The representable
  // Double boundary values are powers of two, so the invalid checks are phrased
  // as half-open ranges around 2^63 and 2^64 before doing any host conversion.
  let rounded = fp_round_to_integer(value, mode)
  let signed_min = -9223372036854775808.0
  let signed_limit = 9223372036854775808.0
  let unsigned_limit = 18446744073709551616.0
  let invalid = if unsigned {
    source_nan || rounded < 0.0 || rounded >= unsigned_limit
  } else {
    source_nan || rounded < signed_min || rounded >= signed_limit
  }
  let result_bits = if invalid {
    self.set_fflags(fp_fflag_nv)
    if source_nan ||
      rounded >= (if unsigned { unsigned_limit } else { signed_limit }) {
      if unsigned {
        0xffffffffffffffffUL
      } else {
        0x7fffffffffffffffUL
      }
    } else if unsigned {
      0U.to_uint64()
    } else {
      0x8000000000000000UL
    }
  } else {
    if rounded != value {
      self.set_fflags(fp_fflag_nx)
    }
    if unsigned {
      UInt64::trunc_double(rounded)
    } else {
      rounded.to_int64().reinterpret_as_uint64()
    }
  }
  self.write_xlen_reg(rd, result_bits)
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
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      let invalid = f32_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f32_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let result = f32_from_bits(lhs_bits) * f32_from_bits(rhs_bits) +
        f32_from_bits(addend_bits)
      let result_bits = f32_bits_from_host(result)
      let exact = f32_from_bits(lhs_bits).to_double() *
        f32_from_bits(rhs_bits).to_double() +
        f32_from_bits(addend_bits).to_double()
      if !invalid && f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMSubS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      let invalid = f32_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f32_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let result = f32_from_bits(lhs_bits) * f32_from_bits(rhs_bits) -
        f32_from_bits(addend_bits)
      let result_bits = f32_bits_from_host(result)
      let exact = f32_from_bits(lhs_bits).to_double() *
        f32_from_bits(rhs_bits).to_double() -
        f32_from_bits(addend_bits).to_double()
      if !invalid && f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMSubS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      let invalid = f32_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f32_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let product = f32_from_bits(lhs_bits) * f32_from_bits(rhs_bits)
      let addend = f32_from_bits(addend_bits)
      let result = addend - product
      let result_bits = f32_bits_from_host(result)
      let exact = f32_from_bits(addend_bits).to_double() -
        f32_from_bits(lhs_bits).to_double() *
        f32_from_bits(rhs_bits).to_double()
      if !invalid && f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMAddS(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      let invalid = f32_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f32_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let product = f32_from_bits(lhs_bits) * f32_from_bits(rhs_bits)
      let addend = f32_from_bits(addend_bits)
      let result = Float::from_double(0.0) - product - addend
      let result_bits = f32_bits_from_host(result)
      let exact = 0.0 -
        f32_from_bits(lhs_bits).to_double() *
        f32_from_bits(rhs_bits).to_double() -
        f32_from_bits(addend_bits).to_double()
      if !invalid && f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMAddD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      let invalid = f64_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f64_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let result = f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) +
        f64_from_bits(addend_bits)
      let result_bits = f64_bits_from_host(result)
      if !invalid &&
        f64_fmadd_inexact_bits(lhs_bits, rhs_bits, addend_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMSubD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      let invalid = f64_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f64_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let result = f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) -
        f64_from_bits(addend_bits)
      let result_bits = f64_bits_from_host(result)
      if !invalid &&
        f64_fmsub_inexact_bits(lhs_bits, rhs_bits, addend_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMSubD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      let invalid = f64_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f64_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let result = 0.0 -
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) +
        f64_from_bits(addend_bits)
      let result_bits = f64_bits_from_host(result)
      if !invalid &&
        f64_fnmsub_inexact_bits(lhs_bits, rhs_bits, addend_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMAddD(rd, rs1, rs2, rs3, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      let invalid = f64_any_signaling_nan3(lhs_bits, rhs_bits, addend_bits) ||
        f64_mul_is_invalid_bits(lhs_bits, rhs_bits)
      if invalid {
        self.set_fflags(fp_fflag_nv)
      }
      let result = 0.0 -
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) -
        f64_from_bits(addend_bits)
      let result_bits = f64_bits_from_host(result)
      if !invalid &&
        f64_fnmadd_inexact_bits(lhs_bits, rhs_bits, addend_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
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
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_add_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let exact = f32_from_bits(lhs_bits).to_double() +
        f32_from_bits(rhs_bits).to_double()
      let result_bits = f32_bits_from_host(
        f32_from_bits(lhs_bits) + f32_from_bits(rhs_bits),
      )
      if f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FSubS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_add_is_invalid_bits(lhs_bits, rhs_bits ^ 0x80000000U) {
        self.set_fflags(fp_fflag_nv)
      }
      let exact = f32_from_bits(lhs_bits).to_double() -
        f32_from_bits(rhs_bits).to_double()
      let result_bits = f32_bits_from_host(
        f32_from_bits(lhs_bits) - f32_from_bits(rhs_bits),
      )
      if f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMulS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_mul_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let exact = f32_from_bits(lhs_bits).to_double() *
        f32_from_bits(rhs_bits).to_double()
      let result_bits = f32_bits_from_host(
        f32_from_bits(lhs_bits) * f32_from_bits(rhs_bits),
      )
      if f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FDivS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_div_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      if f32_div_by_zero_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_dz)
      }
      let exact = f32_from_bits(lhs_bits).to_double() /
        f32_from_bits(rhs_bits).to_double()
      let result_bits = f32_bits_from_host(
        f32_from_bits(lhs_bits) / f32_from_bits(rhs_bits),
      )
      if f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FSqrtS(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let operand_bits = self.read_freg_single_value_bits(rs1)
      if f32_is_signaling_nan_bits(operand_bits) ||
        f32_sqrt_is_invalid_bits(operand_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let exact = f32_from_bits(operand_bits).to_double().sqrt()
      let result_bits = f32_bits_from_host(f32_from_bits(operand_bits).sqrt())
      if f32_finite_inexact_from_double(exact, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_single_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMinS(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_is_signaling_nan_bits(lhs_bits) ||
        f32_is_signaling_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      self.write_freg_single_bits(rd, f32_min_bits(lhs_bits, rhs_bits))
      self.cpu.pc = next_pc
      Running
    }
    FMaxS(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_is_signaling_nan_bits(lhs_bits) ||
        f32_is_signaling_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      self.write_freg_single_bits(rd, f32_max_bits(lhs_bits, rhs_bits))
      self.cpu.pc = next_pc
      Running
    }
    FSgnjS(rd, rs1, rs2) => {
      let sign_mask = 0x80000000U
      // FSGNJ.S is a floating-point operation, not an FMV transfer. With D
      // present it must validate NaN-boxing on both single-precision operands
      // before selecting magnitude/sign bits, and write a boxed single result.
      let magnitude = self.read_freg_single_value_bits(rs1) & sign_mask.lnot()
      let sign = self.read_freg_single_value_bits(rs2) & sign_mask
      self.write_freg_single_bits(rd, magnitude | sign)
      self.cpu.pc = next_pc
      Running
    }
    FSgnjnS(rd, rs1, rs2) => {
      let sign_mask = 0x80000000U
      let magnitude = self.read_freg_single_value_bits(rs1) & sign_mask.lnot()
      let sign = self.read_freg_single_value_bits(rs2).lnot() & sign_mask
      self.write_freg_single_bits(rd, magnitude | sign)
      self.cpu.pc = next_pc
      Running
    }
    FSgnjxS(rd, rs1, rs2) => {
      let sign_mask = 0x80000000U
      let lhs = self.read_freg_single_value_bits(rs1)
      let rhs = self.read_freg_single_value_bits(rs2)
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
      if f32_is_nan_bits(lhs_bits) || f32_is_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
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
      if f32_is_nan_bits(lhs_bits) || f32_is_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
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
      if f32_is_signaling_nan_bits(lhs_bits) ||
        f32_is_signaling_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
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
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_add_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = f64_bits_from_host(
        f64_from_bits(lhs_bits) + f64_from_bits(rhs_bits),
      )
      if f64_add_inexact_bits(lhs_bits, rhs_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FSubD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_add_is_invalid_bits(lhs_bits, rhs_bits ^ (1U.to_uint64() << 63)) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = f64_bits_from_host(
        f64_from_bits(lhs_bits) - f64_from_bits(rhs_bits),
      )
      if f64_sub_inexact_bits(lhs_bits, rhs_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMulD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_mul_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = f64_bits_from_host(
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits),
      )
      if f64_mul_inexact_bits(lhs_bits, rhs_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FDivD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_div_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      if f64_div_by_zero_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_dz)
      }
      let result_bits = f64_bits_from_host(
        f64_from_bits(lhs_bits) / f64_from_bits(rhs_bits),
      )
      if f64_div_inexact_bits(lhs_bits, rhs_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
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
      let operand_bits = self.read_freg_double_bits(rs1)
      if f64_is_signaling_nan_bits(operand_bits) ||
        f64_sqrt_is_invalid_bits(operand_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = f64_bits_from_host(f64_from_bits(operand_bits).sqrt())
      if f64_sqrt_finite_inexact_from_result(operand_bits, result_bits) {
        self.set_fflags(fp_fflag_nx)
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMinD(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_is_signaling_nan_bits(lhs_bits) ||
        f64_is_signaling_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      self.write_freg_double_bits(rd, f64_min_bits(lhs_bits, rhs_bits))
      self.cpu.pc = next_pc
      Running
    }
    FMaxD(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_is_signaling_nan_bits(lhs_bits) ||
        f64_is_signaling_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      self.write_freg_double_bits(rd, f64_max_bits(lhs_bits, rhs_bits))
      self.cpu.pc = next_pc
      Running
    }
    FLeD(rd, rs1, rs2) => {
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_is_nan_bits(lhs_bits) || f64_is_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
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
      if f64_is_nan_bits(lhs_bits) || f64_is_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
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
      if f64_is_signaling_nan_bits(lhs_bits) ||
        f64_is_signaling_nan_bits(rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
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
    FCvtDS(rd, rs1, rm) => {
      // FCVT.D.S widens exactly and never rounds, but the F/D specs still
      // require normal rm legality checks for static and dynamic encodings.
      if !self.fp_rounding_mode_legal(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
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
      // RV32-width integers are exactly representable as doubles. Like other
      // unaffected rm fields, legal modes are accepted but reserved encodings
      // still trap.
      if !self.fp_rounding_mode_legal(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let signed = sign_extend_64(self.cpu.read_reg(rs1), 32).reinterpret_as_int64()
      self.write_freg_double_bits(rd, f64_bits_from_host(signed.to_double()))
      self.cpu.pc = next_pc
      Running
    }
    FCvtDWU(rd, rs1, rm) => {
      // The full unsigned 32-bit range fits in binary64 without rounding.
      if !self.fp_rounding_mode_legal(rm) {
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
      let bits = self.read_freg_single_value_bits(rs1)
      self.write_fcvt_word_result(
        rd,
        f32_from_bits(bits).to_double(),
        mode,
        f32_is_nan_bits(bits),
        false,
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
      let bits = self.read_freg_single_value_bits(rs1)
      self.write_fcvt_word_result(
        rd,
        f32_from_bits(bits).to_double(),
        mode,
        f32_is_nan_bits(bits),
        true,
      )
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
      let bits = self.read_freg_single_value_bits(rs1)
      self.write_fcvt_long_result(
        rd,
        f32_from_bits(bits).to_double(),
        mode,
        f32_is_nan_bits(bits),
        false,
      )
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
      let bits = self.read_freg_single_value_bits(rs1)
      self.write_fcvt_long_result(
        rd,
        f32_from_bits(bits).to_double(),
        mode,
        f32_is_nan_bits(bits),
        true,
      )
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
      let bits = self.read_freg_double_bits(rs1)
      self.write_fcvt_word_result(
        rd,
        f64_from_bits(bits),
        mode,
        f64_is_nan_bits(bits),
        false,
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
      let bits = self.read_freg_double_bits(rs1)
      self.write_fcvt_word_result(
        rd,
        f64_from_bits(bits),
        mode,
        f64_is_nan_bits(bits),
        true,
      )
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
      let bits = self.read_freg_double_bits(rs1)
      self.write_fcvt_long_result(
        rd,
        f64_from_bits(bits),
        mode,
        f64_is_nan_bits(bits),
        false,
      )
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
      let bits = self.read_freg_double_bits(rs1)
      self.write_fcvt_long_result(
        rd,
        f64_from_bits(bits),
        mode,
        f64_is_nan_bits(bits),
        true,
      )
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected fp dispatch")
  }
}
