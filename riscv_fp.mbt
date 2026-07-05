// Scalar F/D execution helpers. The implementation follows the constrained
// host-IEEE contract documented for this repo and keeps NaN-boxing behavior
// visible in tests.

///|
let fp_fflag_nv : UInt64 = 0x10U.to_uint64()

///|
let fp_fflag_dz : UInt64 = 0x08U.to_uint64()

///|
let fp_fflag_of : UInt64 = 0x04U.to_uint64()

///|
let fp_fflag_uf : UInt64 = 0x02U.to_uint64()

///|
let fp_fflag_nx : UInt64 = 0x01U.to_uint64()

///|
fn Runner::fp_has_d(self : Runner) -> Bool {
  (self.config.extensions & MISA_EXT_D) != 0U.to_uint64()
}

///|
fn Runner::fp_context_enabled(self : Runner) -> Bool {
  // The privileged spec uses mstatus.FS=Off as a context-management trap
  // point. MISA.F/D only says the instructions exist; FS decides whether the
  // current software context may execute them.
  (self.cpu.read_csr(CSR_MSTATUS) & MSTATUS_FS_MASK) != 0U.to_uint64()
}

///|
fn Runner::mark_fp_context_dirty(self : Runner) -> Unit {
  // The emulator models only FS today, so dirtying the FP context is the whole
  // SD summary source. Keeping this at write boundaries avoids scattering
  // mstatus knowledge across every individual F/D instruction case.
  let status = self.cpu.read_csr(CSR_MSTATUS)
  if (status & MSTATUS_FS_MASK) != MSTATUS_FS_DIRTY {
    let next = (status & bit_not(MSTATUS_FS_MASK)) | MSTATUS_FS_DIRTY
    self.cpu.write_csr(CSR_MSTATUS, next)
  }
}

///|
fn Runner::write_freg_single_bits(
  self : Runner,
  rd : Int,
  value : UInt,
) -> Unit {
  self.mark_fp_context_dirty()
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
  // Non-transfer single-precision operations validate NaN boxing when FLEN is
  // wider than 32 bits. Valid boxes keep their low payload bits unchanged;
  // malformed boxes are consumed as the architectural single canonical NaN.
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
  self.mark_fp_context_dirty()
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
fn f32_negative_zero_bits() -> UInt {
  1U << 31
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
fn f64_negative_zero_bits() -> UInt64 {
  1U.to_uint64() << 63
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
priv struct FpExactRational {
  num : BigInt
  den : BigInt
}

///|
priv struct FpIntMagnitude {
  sign : Bool
  magnitude : UInt64
}

///|
priv struct FpRoundedIntegerBits {
  bits : UInt64
  inexact : Bool
}

///|
priv struct FpRoundedSingleBits {
  bits : UInt
  flags : UInt64
}

///|
priv struct FpRoundedDoubleBits {
  bits : UInt64
  flags : UInt64
}

///|
priv struct FpRoundedBigInt {
  value : BigInt
  inexact : Bool
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
fn fp_exact_rational_from_f32_bits(bits : UInt) -> FpExactRational? {
  if f32_is_nan_bits(bits) || f32_is_infinite_bits(bits) {
    None
  } else {
    let sign = bits >> 31 != 0U
    let exponent = ((bits >> 23) & 0xffU).reinterpret_as_int()
    let fraction = bits & 0x007fffffU
    let mantissa = if exponent == 0 { fraction } else { (1U << 23) | fraction }
    if mantissa == 0U {
      Some({ num: BigInt::from_int(0), den: fp_bigint_one() })
    } else {
      let exp2 = if exponent == 0 { 1 - 127 - 23 } else { exponent - 127 - 23 }
      let magnitude = BigInt::from_uint64(mantissa.to_uint64())
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
fn fp_exact_rational_compare(
  lhs : FpExactRational,
  rhs : FpExactRational,
) -> Int {
  (lhs.num * rhs.den).compare(rhs.num * lhs.den)
}

///|
fn fp_bigint_abs(value : BigInt) -> BigInt {
  if value < BigInt::from_int(0) {
    -value
  } else {
    value
  }
}

///|
fn fp_compare_to_scaled_power(
  numerator : BigInt,
  denominator : BigInt,
  exponent : Int,
) -> Int {
  // Compare numerator / denominator with 2^exponent without converting through
  // host floating point. This is used to find the architectural binary exponent
  // before rounding a finite exact rational back to IEEE bits.
  if exponent >= 0 {
    numerator.compare(denominator << exponent)
  } else {
    (numerator << (0 - exponent)).compare(denominator)
  }
}

///|
fn fp_exact_rational_floor_log2(
  numerator : BigInt,
  denominator : BigInt,
) -> Int {
  // bit_length gives a close estimate for floor(log2(numerator/denominator)).
  // The two local adjustments handle cases where numerator and denominator have
  // similar top bits and the first estimate lands one step off.
  let estimate = numerator.bit_length() - denominator.bit_length()
  let lower = if fp_compare_to_scaled_power(numerator, denominator, estimate) <
    0 {
    estimate - 1
  } else {
    estimate
  }
  if fp_compare_to_scaled_power(numerator, denominator, lower + 1) >= 0 {
    lower + 1
  } else {
    lower
  }
}

///|
fn fp_round_rational_to_integer(
  numerator : BigInt,
  denominator : BigInt,
  sign : Bool,
  mode : UInt,
) -> FpRoundedBigInt {
  let quotient = numerator / denominator
  let remainder = numerator % denominator
  let inexact = !remainder.is_zero()
  let doubled = remainder << 1
  let tie = doubled == denominator
  let above_half = doubled > denominator
  let round_up = match mode {
    0U =>
      above_half ||
      (tie && quotient % BigInt::from_int(2) != BigInt::from_int(0))
    1U => false
    2U => sign && inexact
    3U => !sign && inexact
    4U => above_half || tie
    _ => false
  }
  {
    value: if round_up {
      quotient + BigInt::from_int(1)
    } else {
      quotient
    },
    inexact,
  }
}

///|
fn fp_round_rational_scaled_to_integer(
  numerator : BigInt,
  denominator : BigInt,
  binary_shift : Int,
  sign : Bool,
  mode : UInt,
) -> FpRoundedBigInt {
  if binary_shift >= 0 {
    fp_round_rational_to_integer(
      numerator << binary_shift,
      denominator,
      sign,
      mode,
    )
  } else {
    fp_round_rational_to_integer(
      numerator,
      denominator << (0 - binary_shift),
      sign,
      mode,
    )
  }
}

///|
fn fp_f64_overflow_bits(sign : Bool, mode : UInt) -> UInt64 {
  let use_infinity = match mode {
    1U => false
    2U => sign
    3U => !sign
    _ => true
  }
  if use_infinity {
    if sign {
      0xfff0000000000000UL
    } else {
      0x7ff0000000000000UL
    }
  } else if sign {
    0xffefffffffffffffUL
  } else {
    0x7fefffffffffffffUL
  }
}

///|
fn fp_round_rational_to_f32_bits(
  exact : FpExactRational,
  mode : UInt,
) -> FpRoundedSingleBits {
  let sign = exact.num < BigInt::from_int(0)
  let sign_bits = if sign { 1U << 31 } else { 0U }
  let numerator = fp_bigint_abs(exact.num)
  if numerator.is_zero() {
    { bits: sign_bits, flags: 0U.to_uint64() }
  } else {
    let exponent = fp_exact_rational_floor_log2(numerator, exact.den)
    if exponent > 127 {
      {
        bits: fp_f32_overflow_bits(sign, mode),
        flags: fp_fflag_of | fp_fflag_nx,
      }
    } else if exponent >= -126 {
      // Normal singles carry 24 bits of precision including the hidden leading
      // one. This is the fused-operation path: no host-Double intermediate is
      // allowed to round the product-plus-addend before the final f32 result.
      let rounded = fp_round_rational_scaled_to_integer(
        numerator,
        exact.den,
        23 - exponent,
        sign,
        mode,
      )
      let mut significand = rounded.value
      let mut stored_exponent = exponent + 127
      if significand == fp_bigint_one() << 24 {
        significand = significand >> 1
        stored_exponent += 1
      }
      if stored_exponent >= 255 {
        {
          bits: fp_f32_overflow_bits(sign, mode),
          flags: fp_fflag_of | fp_fflag_nx,
        }
      } else {
        let exponent_bits = stored_exponent.reinterpret_as_uint() << 23
        let fraction_bits = (significand - (fp_bigint_one() << 23))
          .to_uint64()
          .to_uint()
        {
          bits: sign_bits | exponent_bits | fraction_bits,
          flags: if rounded.inexact {
            fp_fflag_nx
          } else {
            0U.to_uint64()
          },
        }
      }
    } else {
      // Subnormal singles are rounded in units of 2^-149. If rounding reaches
      // the minimum normal, tininess-after-rounding means UF is not accrued.
      let rounded = fp_round_rational_scaled_to_integer(
        numerator,
        exact.den,
        149,
        sign,
        mode,
      )
      if rounded.value >= fp_bigint_one() << 23 {
        {
          bits: sign_bits | (1U << 23),
          flags: if rounded.inexact {
            fp_fflag_nx
          } else {
            0U.to_uint64()
          },
        }
      } else {
        {
          bits: sign_bits | rounded.value.to_uint64().to_uint(),
          flags: if rounded.inexact {
            fp_fflag_uf | fp_fflag_nx
          } else {
            0U.to_uint64()
          },
        }
      }
    }
  }
}

///|
fn f64_exact_zero_add_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  mode : UInt,
) -> UInt64 {
  // For exact zero sums, IEEE keeps a negative zero for two negative zero
  // inputs and otherwise produces -0 only under round-down. FSUB calls this
  // helper with the right-hand sign already flipped.
  let lhs_negative = f64_sign_bit(lhs_bits)
  let rhs_negative = f64_sign_bit(rhs_bits)
  let negative = if f64_is_zero_bits(lhs_bits) &&
    f64_is_zero_bits(rhs_bits) &&
    lhs_negative == rhs_negative {
    lhs_negative
  } else {
    mode == 2U
  }
  if negative {
    f64_negative_zero_bits()
  } else {
    0U.to_uint64()
  }
}

///|
fn fp_exact_zero_sum_is_negative(
  lhs_is_zero : Bool,
  lhs_negative : Bool,
  rhs_is_zero : Bool,
  rhs_negative : Bool,
  mode : UInt,
) -> Bool {
  // Exact zero from adding two signed zeros preserves their shared sign. All
  // other exact cancellations produce +0 except under round-down, where IEEE
  // directed rounding chooses -0.
  if lhs_is_zero && rhs_is_zero && lhs_negative == rhs_negative {
    lhs_negative
  } else {
    mode == 2U
  }
}

///|
fn f32_exact_zero_fma_bits(
  lhs_bits : UInt,
  rhs_bits : UInt,
  addend_bits : UInt,
  mode : UInt,
  variant : Int,
) -> UInt {
  let product_negative = f32_sign_bit(lhs_bits) != f32_sign_bit(rhs_bits)
  let adjusted_product_negative = (variant >= 2) != product_negative
  let adjusted_addend_negative = if variant == 1 || variant == 3 {
    !f32_sign_bit(addend_bits)
  } else {
    f32_sign_bit(addend_bits)
  }
  let negative = fp_exact_zero_sum_is_negative(
    f32_is_zero_bits(lhs_bits) || f32_is_zero_bits(rhs_bits),
    adjusted_product_negative,
    f32_is_zero_bits(addend_bits),
    adjusted_addend_negative,
    mode,
  )
  if negative {
    f32_negative_zero_bits()
  } else {
    0U
  }
}

///|
fn f64_exact_zero_fma_bits(
  lhs_bits : UInt64,
  rhs_bits : UInt64,
  addend_bits : UInt64,
  mode : UInt,
  variant : Int,
) -> UInt64 {
  let product_negative = f64_sign_bit(lhs_bits) != f64_sign_bit(rhs_bits)
  let adjusted_product_negative = (variant >= 2) != product_negative
  let adjusted_addend_negative = if variant == 1 || variant == 3 {
    !f64_sign_bit(addend_bits)
  } else {
    f64_sign_bit(addend_bits)
  }
  let negative = fp_exact_zero_sum_is_negative(
    f64_is_zero_bits(lhs_bits) || f64_is_zero_bits(rhs_bits),
    adjusted_product_negative,
    f64_is_zero_bits(addend_bits),
    adjusted_addend_negative,
    mode,
  )
  if negative {
    f64_negative_zero_bits()
  } else {
    0U.to_uint64()
  }
}

///|
fn f64_exact_zero_mul_bits(lhs_bits : UInt64, rhs_bits : UInt64) -> UInt64 {
  if f64_sign_bit(lhs_bits) != f64_sign_bit(rhs_bits) {
    f64_negative_zero_bits()
  } else {
    0U.to_uint64()
  }
}

///|
fn f64_exact_zero_div_bits(lhs_bits : UInt64, rhs_bits : UInt64) -> UInt64 {
  if f64_sign_bit(lhs_bits) != f64_sign_bit(rhs_bits) {
    f64_negative_zero_bits()
  } else {
    0U.to_uint64()
  }
}

///|
fn fp_round_rational_to_f64_bits(
  exact : FpExactRational,
  mode : UInt,
) -> FpRoundedDoubleBits {
  let sign = exact.num < BigInt::from_int(0)
  let sign_bits = if sign { 1U.to_uint64() << 63 } else { 0U.to_uint64() }
  let numerator = fp_bigint_abs(exact.num)
  if numerator.is_zero() {
    { bits: sign_bits, flags: 0U.to_uint64() }
  } else {
    let exponent = fp_exact_rational_floor_log2(numerator, exact.den)
    if exponent > 1023 {
      {
        bits: fp_f64_overflow_bits(sign, mode),
        flags: fp_fflag_of | fp_fflag_nx,
      }
    } else if exponent >= -1022 {
      // Normal doubles carry 53 bits of precision including the hidden leading
      // one. Round the exact value after scaling that leading bit to bit 52.
      let rounded = fp_round_rational_scaled_to_integer(
        numerator,
        exact.den,
        52 - exponent,
        sign,
        mode,
      )
      let mut significand = rounded.value
      let mut stored_exponent = exponent + 1023
      if significand == fp_bigint_one() << 53 {
        significand = significand >> 1
        stored_exponent += 1
      }
      if stored_exponent >= 2047 {
        {
          bits: fp_f64_overflow_bits(sign, mode),
          flags: fp_fflag_of | fp_fflag_nx,
        }
      } else {
        let exponent_bits = stored_exponent.reinterpret_as_uint().to_uint64() <<
          52
        let fraction_bits = (significand - (fp_bigint_one() << 52)).to_uint64()
        {
          bits: sign_bits | exponent_bits | fraction_bits,
          flags: if rounded.inexact {
            fp_fflag_nx
          } else {
            0U.to_uint64()
          },
        }
      }
    } else {
      // Subnormal doubles have no hidden bit. Scale directly to units of
      // 2^-1074; if rounding reaches the minimum normal, tininess-after-rounding
      // means UF is not accrued.
      let rounded = fp_round_rational_scaled_to_integer(
        numerator,
        exact.den,
        1074,
        sign,
        mode,
      )
      if rounded.value >= fp_bigint_one() << 52 {
        {
          bits: sign_bits | (1U.to_uint64() << 52),
          flags: if rounded.inexact {
            fp_fflag_nx
          } else {
            0U.to_uint64()
          },
        }
      } else {
        {
          bits: sign_bits | rounded.value.to_uint64(),
          flags: if rounded.inexact {
            fp_fflag_uf | fp_fflag_nx
          } else {
            0U.to_uint64()
          },
        }
      }
    }
  }
}

///|
fn f64_next_up_positive_finite(bits : UInt64) -> UInt64 {
  if bits == 0x7ff0000000000000UL {
    bits
  } else {
    bits + 1UL
  }
}

///|
fn f64_next_down_positive_finite(bits : UInt64) -> UInt64 {
  if bits == 0UL {
    bits
  } else {
    bits - 1UL
  }
}

///|
fn f64_sqrt_rounded_bits(
  operand_bits : UInt64,
  mode : UInt,
) -> FpRoundedDoubleBits {
  let host_bits = f64_bits_from_host(f64_from_bits(operand_bits).sqrt())
  match fp_exact_rational_from_f64_bits(operand_bits) {
    Some(operand) => {
      if operand.num <= BigInt::from_int(0) {
        return { bits: host_bits, flags: 0UL }
      }
      match fp_exact_rational_from_f64_bits(host_bits) {
        Some(host) => {
          let squared = fp_exact_rational_mul(host, host)
          let square_compare = fp_exact_rational_compare(squared, operand)
          if square_compare == 0 {
            return { bits: host_bits, flags: 0UL }
          }
          let (lower_bits, upper_bits) = if square_compare < 0 {
            (host_bits, f64_next_up_positive_finite(host_bits))
          } else {
            (f64_next_down_positive_finite(host_bits), host_bits)
          }
          let bits = match mode {
            // The square root of a positive finite value is non-negative, so
            // RTZ and RDN both choose the representable value below the exact
            // root while RUP chooses the value above it.
            1 => lower_bits
            2 => lower_bits
            3 => upper_bits
            4 => {
              let lower = fp_exact_rational_from_f64_bits(lower_bits).unwrap()
              let upper = fp_exact_rational_from_f64_bits(upper_bits).unwrap()
              let midpoint = fp_exact_rational_div(
                fp_exact_rational_add(lower, upper),
                { num: BigInt::from_int(2), den: fp_bigint_one() },
              ).unwrap()
              let midpoint_squared = fp_exact_rational_mul(midpoint, midpoint)
              if fp_exact_rational_compare(operand, midpoint_squared) < 0 {
                lower_bits
              } else {
                upper_bits
              }
            }
            _ => host_bits
          }
          { bits, flags: fp_fflag_nx }
        }
        None => { bits: host_bits, flags: 0UL }
      }
    }
    None => { bits: host_bits, flags: 0UL }
  }
}

///|
fn f32_round_fused_result_bits(
  lhs_bits : UInt,
  rhs_bits : UInt,
  addend_bits : UInt,
  mode : UInt,
  host_result_bits : UInt64,
  variant : Int,
) -> FpRoundedSingleBits {
  let fallback = fp_round_f64_bits_to_f32_bits(host_result_bits, mode)
  match
    (
      fp_exact_rational_from_f32_bits(lhs_bits),
      fp_exact_rational_from_f32_bits(rhs_bits),
      fp_exact_rational_from_f32_bits(addend_bits),
    ) {
    (Some(lhs), Some(rhs), Some(addend)) => {
      let product = fp_exact_rational_mul(lhs, rhs)
      let exact = match variant {
        0 => fp_exact_rational_add(product, addend)
        1 => fp_exact_rational_sub(product, addend)
        2 => fp_exact_rational_sub(addend, product)
        _ => fp_exact_rational_sub(fp_exact_rational_neg(product), addend)
      }
      if exact.num.is_zero() {
        {
          bits: f32_exact_zero_fma_bits(
            lhs_bits, rhs_bits, addend_bits, mode, variant,
          ),
          flags: 0U.to_uint64(),
        }
      } else {
        fp_round_rational_to_f32_bits(exact, mode)
      }
    }
    _ => fallback
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
fn f32_mul_result_is_infinite_bits(lhs : UInt, rhs : UInt) -> Bool {
  !f32_is_nan_bits(lhs) &&
  !f32_is_nan_bits(rhs) &&
  (
    (f32_is_infinite_bits(lhs) && !f32_is_zero_bits(rhs)) ||
    (f32_is_infinite_bits(rhs) && !f32_is_zero_bits(lhs))
  )
}

///|
fn f64_mul_result_is_infinite_bits(lhs : UInt64, rhs : UInt64) -> Bool {
  !f64_is_nan_bits(lhs) &&
  !f64_is_nan_bits(rhs) &&
  (
    (f64_is_infinite_bits(lhs) && !f64_is_zero_bits(rhs)) ||
    (f64_is_infinite_bits(rhs) && !f64_is_zero_bits(lhs))
  )
}

///|
fn fp_fma_infinite_terms_cancel(
  product_negative : Bool,
  addend_negative : Bool,
  variant : Int,
) -> Bool {
  // The four RISC-V FMA opcodes differ only by which term signs are flipped
  // before the fused add. If the effective product term and addend term are
  // opposite infinities, the mathematical sum is undefined and must raise NV.
  let effective_product_negative = match variant {
    2 | 3 => !product_negative
    _ => product_negative
  }
  let effective_addend_negative = match variant {
    1 | 3 => !addend_negative
    _ => addend_negative
  }
  effective_product_negative != effective_addend_negative
}

///|
fn f32_fma_infinite_add_is_invalid_bits(
  lhs : UInt,
  rhs : UInt,
  addend : UInt,
  variant : Int,
) -> Bool {
  f32_mul_result_is_infinite_bits(lhs, rhs) &&
  f32_is_infinite_bits(addend) &&
  fp_fma_infinite_terms_cancel(
    f32_sign_bit(lhs) != f32_sign_bit(rhs),
    f32_sign_bit(addend),
    variant,
  )
}

///|
fn f64_fma_infinite_add_is_invalid_bits(
  lhs : UInt64,
  rhs : UInt64,
  addend : UInt64,
  variant : Int,
) -> Bool {
  f64_mul_result_is_infinite_bits(lhs, rhs) &&
  f64_is_infinite_bits(addend) &&
  fp_fma_infinite_terms_cancel(
    f64_sign_bit(lhs) != f64_sign_bit(rhs),
    f64_sign_bit(addend),
    variant,
  )
}

///|
fn f32_fma_is_invalid_bits(
  lhs : UInt,
  rhs : UInt,
  addend : UInt,
  variant : Int,
) -> Bool {
  // Fused multiply-add has the ordinary signaling-NaN invalid cases plus the
  // IEEE invalid multiplication form infinity*zero and the invalid fused add
  // of opposite infinities. Once any condition is present, RISC-V writes the
  // canonical NaN instead of exposing host NaN payload or sign propagation.
  f32_any_signaling_nan3(lhs, rhs, addend) ||
  f32_mul_is_invalid_bits(lhs, rhs) ||
  f32_fma_infinite_add_is_invalid_bits(lhs, rhs, addend, variant)
}

///|
fn f64_fma_is_invalid_bits(
  lhs : UInt64,
  rhs : UInt64,
  addend : UInt64,
  variant : Int,
) -> Bool {
  f64_any_signaling_nan3(lhs, rhs, addend) ||
  f64_mul_is_invalid_bits(lhs, rhs) ||
  f64_fma_infinite_add_is_invalid_bits(lhs, rhs, addend, variant)
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
  // FSQRT invalid-operation is for negative numeric inputs other than -0.
  // NaNs follow the normal NaN path: signaling NaNs set NV, quiet NaNs do not.
  f32_sign_bit(value) && !f32_is_zero_bits(value) && !f32_is_nan_bits(value)
}

///|
fn f64_sqrt_is_invalid_bits(value : UInt64) -> Bool {
  f64_sign_bit(value) && !f64_is_zero_bits(value) && !f64_is_nan_bits(value)
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
  self.mark_fp_context_dirty()
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
fn fp_signed_integer_magnitude(value : UInt64) -> FpIntMagnitude {
  let sign = value >> 63 != 0U.to_uint64()
  if sign {
    { sign, magnitude: bit_not(value) + 1U.to_uint64() }
  } else {
    { sign, magnitude: value }
  }
}

///|
fn fp_u64_msb_index(value : UInt64) -> Int {
  let mut rest = value
  let mut index = 0
  while rest >> 1 != 0U.to_uint64() {
    rest = rest >> 1
    index += 1
  }
  index
}

///|
fn fp_round_integer_should_increment(
  sign : Bool,
  retained : UInt64,
  remainder : UInt64,
  half : UInt64,
  mode : UInt,
) -> Bool {
  match mode {
    0U =>
      remainder > half ||
      (remainder == half && (retained & 1U.to_uint64()) != 0U.to_uint64())
    1U => false
    2U => sign && remainder != 0U.to_uint64()
    3U => !sign && remainder != 0U.to_uint64()
    4U => remainder >= half
    _ => false
  }
}

///|
fn fp_round_scaled_u64_to_integer(
  magnitude : UInt64,
  scale_shift : Int,
  sign : Bool,
  mode : UInt,
) -> FpRoundedIntegerBits {
  if scale_shift >= 0 {
    { bits: magnitude << scale_shift, inexact: false }
  } else {
    let shift = 0 - scale_shift
    if shift >= 64 {
      let increment = match mode {
        2U => sign && magnitude != 0U.to_uint64()
        3U => !sign && magnitude != 0U.to_uint64()
        _ => false
      }
      {
        bits: if increment {
          1U.to_uint64()
        } else {
          0U.to_uint64()
        },
        inexact: magnitude != 0U.to_uint64(),
      }
    } else {
      let retained = magnitude >> shift
      let remainder_mask = (1U.to_uint64() << shift) - 1U.to_uint64()
      let remainder = magnitude & remainder_mask
      let half = 1U.to_uint64() << (shift - 1)
      let increment = fp_round_integer_should_increment(
        sign, retained, remainder, half, mode,
      )
      {
        bits: if increment {
          retained + 1U.to_uint64()
        } else {
          retained
        },
        inexact: remainder != 0U.to_uint64(),
      }
    }
  }
}

///|
fn fp_round_u64_to_ieee_bits(
  magnitude : UInt64,
  sign : Bool,
  mode : UInt,
  fraction_bits : Int,
  exponent_bias : Int,
  sign_shift : Int,
) -> FpRoundedIntegerBits {
  if magnitude == 0U.to_uint64() {
    let sign_bits = if sign {
      1U.to_uint64() << sign_shift
    } else {
      0U.to_uint64()
    }
    { bits: sign_bits, inexact: false }
  } else {
    let precision = fraction_bits + 1
    let msb = fp_u64_msb_index(magnitude)
    let mut exponent = msb + exponent_bias
    let mut significand = 0U.to_uint64()
    let mut inexact = false
    if msb < precision {
      significand = magnitude << (precision - 1 - msb)
    } else {
      let shift = msb - (precision - 1)
      let retained = magnitude >> shift
      let remainder_mask = (1U.to_uint64() << shift) - 1U.to_uint64()
      let remainder = magnitude & remainder_mask
      let half = 1U.to_uint64() << (shift - 1)
      inexact = remainder != 0U.to_uint64()
      significand = retained
      if fp_round_integer_should_increment(
          sign, retained, remainder, half, mode,
        ) {
        significand += 1U.to_uint64()
        if significand == 1U.to_uint64() << precision {
          significand = significand >> 1
          exponent += 1
        }
      }
    }
    let sign_bits = if sign {
      1U.to_uint64() << sign_shift
    } else {
      0U.to_uint64()
    }
    let exponent_bits = exponent.reinterpret_as_uint().to_uint64() <<
      fraction_bits
    let fraction_mask = (1U.to_uint64() << fraction_bits) - 1U.to_uint64()
    { bits: sign_bits | exponent_bits | (significand & fraction_mask), inexact }
  }
}

///|
fn fp_f32_overflow_bits(sign : Bool, mode : UInt) -> UInt {
  let use_infinity = match mode {
    1U => false
    2U => sign
    3U => !sign
    _ => true
  }
  if use_infinity {
    if sign {
      0xff800000U
    } else {
      0x7f800000U
    }
  } else if sign {
    0xff7fffffU
  } else {
    0x7f7fffffU
  }
}

///|
fn fp_round_f64_bits_to_f32_bits(
  bits : UInt64,
  mode : UInt,
) -> FpRoundedSingleBits {
  let sign = f64_sign_bit(bits)
  let sign_bits = if sign { 0x80000000U } else { 0U }
  if f64_is_nan_bits(bits) {
    let flags = if f64_is_signaling_nan_bits(bits) {
      fp_fflag_nv
    } else {
      0U.to_uint64()
    }
    { bits: f32_canonical_nan_bits(), flags }
  } else if f64_is_infinite_bits(bits) {
    { bits: sign_bits | 0x7f800000U, flags: 0U.to_uint64() }
  } else {
    let exponent = ((bits >> 52) & 0x7ffU.to_uint64()).to_int()
    let fraction = bits & ((1U.to_uint64() << 52) - 1U.to_uint64())
    let mantissa = if exponent == 0 {
      fraction
    } else {
      (1U.to_uint64() << 52) | fraction
    }
    if mantissa == 0U.to_uint64() {
      { bits: sign_bits, flags: 0U.to_uint64() }
    } else {
      let exp2 = if exponent == 0 {
        1 - 1023 - 52
      } else {
        exponent - 1023 - 52
      }
      let unbiased = exp2 + fp_u64_msb_index(mantissa)
      if unbiased > 127 {
        {
          bits: fp_f32_overflow_bits(sign, mode),
          flags: fp_fflag_of | fp_fflag_nx,
        }
      } else if unbiased >= -126 {
        let rounded = fp_round_scaled_u64_to_integer(
          mantissa,
          exp2 - (unbiased - 23),
          sign,
          mode,
        )
        let mut significand = rounded.bits
        let mut stored_exponent = unbiased + 127
        if significand == 1U.to_uint64() << 24 {
          significand = significand >> 1
          stored_exponent += 1
        }
        if stored_exponent >= 255 {
          {
            bits: fp_f32_overflow_bits(sign, mode),
            flags: fp_fflag_of | fp_fflag_nx,
          }
        } else {
          let exponent_bits = stored_exponent.reinterpret_as_uint() << 23
          let fraction_bits = significand.to_uint() & 0x007fffffU
          {
            bits: sign_bits | exponent_bits | fraction_bits,
            flags: if rounded.inexact {
              fp_fflag_nx
            } else {
              0U.to_uint64()
            },
          }
        }
      } else {
        let rounded = fp_round_scaled_u64_to_integer(
          mantissa,
          exp2 + 149,
          sign,
          mode,
        )
        if rounded.bits >= 1U.to_uint64() << 23 {
          // RISC-V follows IEEE tininess-after-rounding. A tiny exact value
          // that rounds up to the minimum normal single is inexact but no
          // longer tiny after rounding, so it must not accrue UF.
          {
            bits: sign_bits | 0x00800000U,
            flags: if rounded.inexact {
              fp_fflag_nx
            } else {
              0U.to_uint64()
            },
          }
        } else {
          {
            bits: sign_bits | rounded.bits.to_uint(),
            flags: if rounded.inexact {
              fp_fflag_uf | fp_fflag_nx
            } else {
              0U.to_uint64()
            },
          }
        }
      }
    }
  }
}

///|
fn Runner::write_fcvt_single_from_integer(
  self : Runner,
  rd : Int,
  sign : Bool,
  magnitude : UInt64,
  mode : UInt,
) -> Unit {
  let rounded = fp_round_u64_to_ieee_bits(magnitude, sign, mode, 23, 127, 31)
  if rounded.inexact {
    self.set_fflags(fp_fflag_nx)
  }
  self.write_freg_single_bits(rd, rounded.bits.to_uint())
}

///|
fn Runner::write_fcvt_double_from_integer(
  self : Runner,
  rd : Int,
  sign : Bool,
  magnitude : UInt64,
  mode : UInt,
) -> Unit {
  let rounded = fp_round_u64_to_ieee_bits(magnitude, sign, mode, 52, 1023, 63)
  if rounded.inexact {
    self.set_fflags(fp_fflag_nx)
  }
  self.write_freg_double_bits(rd, rounded.bits)
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
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !self.fp_context_enabled() {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
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
  if !self.fp_context_enabled() {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  match instruction {
    FMAddS(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      if f32_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 0) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_single_bits(rd, f32_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = (f32_from_bits(lhs_bits).to_double() *
      f32_from_bits(rhs_bits).to_double() +
      f32_from_bits(addend_bits).to_double()).reinterpret_as_uint64()
      let rounded = f32_round_fused_result_bits(
        lhs_bits, rhs_bits, addend_bits, mode, host_bits, 0,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FMSubS(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      if f32_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 1) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_single_bits(rd, f32_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = (f32_from_bits(lhs_bits).to_double() *
      f32_from_bits(rhs_bits).to_double() -
      f32_from_bits(addend_bits).to_double()).reinterpret_as_uint64()
      let rounded = f32_round_fused_result_bits(
        lhs_bits, rhs_bits, addend_bits, mode, host_bits, 1,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMSubS(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      if f32_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 2) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_single_bits(rd, f32_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = (f32_from_bits(addend_bits).to_double() -
      f32_from_bits(lhs_bits).to_double() * f32_from_bits(rhs_bits).to_double()).reinterpret_as_uint64()
      let rounded = f32_round_fused_result_bits(
        lhs_bits, rhs_bits, addend_bits, mode, host_bits, 2,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMAddS(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      let addend_bits = self.read_freg_single_value_bits(rs3)
      if f32_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 3) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_single_bits(rd, f32_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = (0.0 -
      f32_from_bits(lhs_bits).to_double() * f32_from_bits(rhs_bits).to_double() -
      f32_from_bits(addend_bits).to_double()).reinterpret_as_uint64()
      let rounded = f32_round_fused_result_bits(
        lhs_bits, rhs_bits, addend_bits, mode, host_bits, 3,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FMAddD(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      if f64_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 0) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_double_bits(rd, f64_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = f64_bits_from_host(
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) +
        f64_from_bits(addend_bits),
      )
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
          fp_exact_rational_from_f64_bits(addend_bits),
        ) {
        (Some(lhs), Some(rhs), Some(addend)) => {
          let exact = fp_exact_rational_add(
            fp_exact_rational_mul(lhs, rhs),
            addend,
          )
          if exact.num.is_zero() {
            f64_exact_zero_fma_bits(lhs_bits, rhs_bits, addend_bits, mode, 0)
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ => host_bits
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMSubD(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      if f64_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 1) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_double_bits(rd, f64_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = f64_bits_from_host(
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) -
        f64_from_bits(addend_bits),
      )
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
          fp_exact_rational_from_f64_bits(addend_bits),
        ) {
        (Some(lhs), Some(rhs), Some(addend)) => {
          let exact = fp_exact_rational_sub(
            fp_exact_rational_mul(lhs, rhs),
            addend,
          )
          if exact.num.is_zero() {
            f64_exact_zero_fma_bits(lhs_bits, rhs_bits, addend_bits, mode, 1)
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ => host_bits
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMSubD(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      if f64_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 2) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_double_bits(rd, f64_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = f64_bits_from_host(
        0.0 -
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) +
        f64_from_bits(addend_bits),
      )
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
          fp_exact_rational_from_f64_bits(addend_bits),
        ) {
        (Some(lhs), Some(rhs), Some(addend)) => {
          let exact = fp_exact_rational_sub(
            addend,
            fp_exact_rational_mul(lhs, rhs),
          )
          if exact.num.is_zero() {
            f64_exact_zero_fma_bits(lhs_bits, rhs_bits, addend_bits, mode, 2)
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ => host_bits
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FNMAddD(rd, rs1, rs2, rs3, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      let addend_bits = self.read_freg_double_bits(rs3)
      if f64_fma_is_invalid_bits(lhs_bits, rhs_bits, addend_bits, 3) {
        self.set_fflags(fp_fflag_nv)
        self.write_freg_double_bits(rd, f64_canonical_nan_bits())
        self.cpu.pc = next_pc
        return Running
      }
      let host_bits = f64_bits_from_host(
        0.0 -
        f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits) -
        f64_from_bits(addend_bits),
      )
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
          fp_exact_rational_from_f64_bits(addend_bits),
        ) {
        (Some(lhs), Some(rhs), Some(addend)) => {
          let product = fp_exact_rational_mul(lhs, rhs)
          let exact = fp_exact_rational_sub(
            fp_exact_rational_neg(product),
            addend,
          )
          if exact.num.is_zero() {
            f64_exact_zero_fma_bits(lhs_bits, rhs_bits, addend_bits, mode, 3)
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ => host_bits
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FmvXW(rd, rs1) => {
      // FMV.X.W is a transfer, so it deliberately ignores NaN-boxing metadata
      // and sign-extends only the low IEEE single-precision bit pattern.
      self.write_xlen_reg(
        rd,
        sign_extend_64(self.read_freg_single_transfer_bits(rs1).to_uint64(), 32),
      )
      self.cpu.pc = next_pc
      Running
    }
    FmvWX(rd, rs1) => {
      // The inverse single transfer boxes the raw low word when FLEN=64.
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
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_add_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let rounded = fp_round_f64_bits_to_f32_bits(
        (f32_from_bits(lhs_bits).to_double() +
        f32_from_bits(rhs_bits).to_double()).reinterpret_as_uint64(),
        mode,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FSubS(rd, rs1, rs2, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_add_is_invalid_bits(lhs_bits, rhs_bits ^ 0x80000000U) {
        self.set_fflags(fp_fflag_nv)
      }
      let rounded = fp_round_f64_bits_to_f32_bits(
        (f32_from_bits(lhs_bits).to_double() -
        f32_from_bits(rhs_bits).to_double()).reinterpret_as_uint64(),
        mode,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FMulS(rd, rs1, rs2, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_single_value_bits(rs1)
      let rhs_bits = self.read_freg_single_value_bits(rs2)
      if f32_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f32_mul_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let rounded = fp_round_f64_bits_to_f32_bits(
        (f32_from_bits(lhs_bits).to_double() *
        f32_from_bits(rhs_bits).to_double()).reinterpret_as_uint64(),
        mode,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FDivS(rd, rs1, rs2, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
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
      let rounded = fp_round_f64_bits_to_f32_bits(
        (f32_from_bits(lhs_bits).to_double() /
        f32_from_bits(rhs_bits).to_double()).reinterpret_as_uint64(),
        mode,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FSqrtS(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let operand_bits = self.read_freg_single_value_bits(rs1)
      if f32_is_signaling_nan_bits(operand_bits) ||
        f32_sqrt_is_invalid_bits(operand_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let rounded = fp_round_f64_bits_to_f32_bits(
        f32_from_bits(operand_bits).to_double().sqrt().reinterpret_as_uint64(),
        mode,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
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
      // FSGNJ.S is not a transfer, so D-present single operands still pass
      // through the NaN-boxing input rule. Once an operand is a valid box,
      // sign-injection itself only rewrites sign bits: it does not canonicalize
      // NaN payloads and does not accrue fflags.
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
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_add_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
        ) {
        (Some(lhs), Some(rhs)) => {
          let exact = fp_exact_rational_add(lhs, rhs)
          if exact.num.is_zero() {
            f64_exact_zero_add_bits(lhs_bits, rhs_bits, mode)
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ =>
          f64_bits_from_host(f64_from_bits(lhs_bits) + f64_from_bits(rhs_bits))
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FSubD(rd, rs1, rs2, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_add_is_invalid_bits(lhs_bits, rhs_bits ^ (1U.to_uint64() << 63)) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
        ) {
        (Some(lhs), Some(rhs)) => {
          let exact = fp_exact_rational_sub(lhs, rhs)
          if exact.num.is_zero() {
            f64_exact_zero_add_bits(
              lhs_bits,
              rhs_bits ^ (1U.to_uint64() << 63),
              mode,
            )
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ =>
          f64_bits_from_host(f64_from_bits(lhs_bits) - f64_from_bits(rhs_bits))
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FMulD(rd, rs1, rs2, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let lhs_bits = self.read_freg_double_bits(rs1)
      let rhs_bits = self.read_freg_double_bits(rs2)
      if f64_any_signaling_nan2(lhs_bits, rhs_bits) ||
        f64_mul_is_invalid_bits(lhs_bits, rhs_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
        ) {
        (Some(lhs), Some(rhs)) => {
          let exact = fp_exact_rational_mul(lhs, rhs)
          if exact.num.is_zero() {
            f64_exact_zero_mul_bits(lhs_bits, rhs_bits)
          } else {
            let rounded = fp_round_rational_to_f64_bits(exact, mode)
            self.set_fflags(rounded.flags)
            rounded.bits
          }
        }
        _ =>
          f64_bits_from_host(f64_from_bits(lhs_bits) * f64_from_bits(rhs_bits))
      }
      self.write_freg_double_bits(rd, result_bits)
      self.cpu.pc = next_pc
      Running
    }
    FDivD(rd, rs1, rs2, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
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
      let result_bits = match
        (
          fp_exact_rational_from_f64_bits(lhs_bits),
          fp_exact_rational_from_f64_bits(rhs_bits),
        ) {
        (Some(lhs), Some(rhs)) =>
          match fp_exact_rational_div(lhs, rhs) {
            Some(exact) =>
              if exact.num.is_zero() {
                f64_exact_zero_div_bits(lhs_bits, rhs_bits)
              } else {
                let rounded = fp_round_rational_to_f64_bits(exact, mode)
                self.set_fflags(rounded.flags)
                rounded.bits
              }
            None =>
              f64_bits_from_host(
                f64_from_bits(lhs_bits) / f64_from_bits(rhs_bits),
              )
          }
        _ =>
          f64_bits_from_host(f64_from_bits(lhs_bits) / f64_from_bits(rhs_bits))
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
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let operand_bits = self.read_freg_double_bits(rs1)
      if f64_is_signaling_nan_bits(operand_bits) ||
        f64_sqrt_is_invalid_bits(operand_bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let rounded = f64_sqrt_rounded_bits(operand_bits, mode)
      self.set_fflags(rounded.flags)
      self.write_freg_double_bits(rd, rounded.bits)
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
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let rounded = fp_round_f64_bits_to_f32_bits(
        self.read_freg_double_bits(rs1),
        mode,
      )
      self.set_fflags(rounded.flags)
      self.write_freg_single_bits(rd, rounded.bits)
      self.cpu.pc = next_pc
      Running
    }
    FCvtDS(rd, rs1, rm) => {
      // FCVT.D.S widens finite values exactly and never rounds. It is still a
      // floating-point operation: reserved rm encodings trap, and signaling
      // single-precision NaNs accrue NV before producing the canonical NaN.
      if !self.fp_rounding_mode_legal(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let bits = self.read_freg_single_value_bits(rs1)
      if f32_is_signaling_nan_bits(bits) {
        self.set_fflags(fp_fflag_nv)
      }
      let result = f32_from_bits(bits).to_double()
      self.write_freg_double_bits(rd, f64_bits_from_host(result))
      self.cpu.pc = next_pc
      Running
    }
    FCvtSW(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let signed = fp_signed_integer_magnitude(
        sign_extend_64(self.cpu.read_reg(rs1), 32),
      )
      self.write_fcvt_single_from_integer(
        rd,
        signed.sign,
        signed.magnitude,
        mode,
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSWU(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let unsigned = self.cpu.read_reg(rs1) & 0xffffffffU.to_uint64()
      self.write_fcvt_single_from_integer(rd, false, unsigned, mode)
      self.cpu.pc = next_pc
      Running
    }
    FCvtSL(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let signed = fp_signed_integer_magnitude(self.cpu.read_reg(rs1))
      self.write_fcvt_single_from_integer(
        rd,
        signed.sign,
        signed.magnitude,
        mode,
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSLU(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      self.write_fcvt_single_from_integer(
        rd,
        false,
        self.cpu.read_reg(rs1),
        mode,
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
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let signed = fp_signed_integer_magnitude(self.cpu.read_reg(rs1))
      self.write_fcvt_double_from_integer(
        rd,
        signed.sign,
        signed.magnitude,
        mode,
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtDLU(rd, rs1, rm) => {
      let mode = match self.fp_effective_rounding_mode(rm) {
        Some(mode) => mode
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      self.write_fcvt_double_from_integer(
        rd,
        false,
        self.cpu.read_reg(rs1),
        mode,
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
