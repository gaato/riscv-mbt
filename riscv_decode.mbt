fn rd(raw : UInt) -> Int {
  ((raw >> 7) & 0x1fU).reinterpret_as_int()
}

///|
fn rs1(raw : UInt) -> Int {
  ((raw >> 15) & 0x1fU).reinterpret_as_int()
}

///|
fn rs2(raw : UInt) -> Int {
  ((raw >> 20) & 0x1fU).reinterpret_as_int()
}

///|
fn funct3(raw : UInt) -> UInt {
  (raw >> 12) & 0x7U
}

///|
fn funct7(raw : UInt) -> UInt {
  (raw >> 25) & 0x7fU
}

///|
fn funct5(raw : UInt) -> UInt {
  (raw >> 27) & 0x1fU
}

///|
fn funct6(raw : UInt) -> UInt {
  (raw >> 26) & 0x3fU
}

///|
fn c_funct3(raw : UInt) -> UInt {
  (raw >> 13) & 0x7U
}

///|
fn instruction_length_from_low16(low16 : UInt) -> Int {
  if (low16 & 0x3U) == 0x3U {
    4
  } else {
    2
  }
}

///|
fn csr_addr(raw : UInt) -> Int {
  ((raw >> 20) & 0xfffU).reinterpret_as_int()
}

///|
fn csr_uimm(raw : UInt) -> UInt {
  (raw >> 15) & 0x1fU
}

///|
fn c_rd_rs1(raw : UInt) -> Int {
  ((raw >> 7) & 0x1fU).reinterpret_as_int()
}

///|
fn c_rs2(raw : UInt) -> Int {
  ((raw >> 2) & 0x1fU).reinterpret_as_int()
}

///|
fn c_rd_prime(raw : UInt) -> Int {
  8 + (((raw >> 2) & 0x7U).reinterpret_as_int())
}

///|
fn c_rs1_prime(raw : UInt) -> Int {
  8 + (((raw >> 7) & 0x7U).reinterpret_as_int())
}

///|
fn c_rs2_prime(raw : UInt) -> Int {
  8 + (((raw >> 2) & 0x7U).reinterpret_as_int())
}

///|
fn sign_extend(value : UInt, bits : Int) -> Int {
  let shift = 32 - bits
  (value << shift).reinterpret_as_int() >> shift
}

///|
fn imm_i(raw : UInt) -> Int {
  sign_extend(raw >> 20, 12)
}

///|
fn shamt_i(raw : UInt) -> Int {
  ((raw >> 20) & 0x3fU).reinterpret_as_int()
}

///|
fn shamt_iw(raw : UInt) -> Int {
  ((raw >> 20) & 0x1fU).reinterpret_as_int()
}

///|
fn imm_s(raw : UInt) -> Int {
  let upper = ((raw >> 25) & 0x7fU) << 5
  let lower = (raw >> 7) & 0x1fU
  sign_extend(upper | lower, 12)
}

///|
fn imm_b(raw : UInt) -> Int {
  let bit12 = ((raw >> 31) & 0x1U) << 12
  let bit11 = ((raw >> 7) & 0x1U) << 11
  let bits10_5 = ((raw >> 25) & 0x3fU) << 5
  let bits4_1 = ((raw >> 8) & 0xfU) << 1
  sign_extend(bit12 | bit11 | bits10_5 | bits4_1, 13)
}

///|
fn imm_u(raw : UInt) -> UInt {
  raw & 0xfffff000U
}

///|
fn imm_j(raw : UInt) -> Int {
  let bit20 = ((raw >> 31) & 0x1U) << 20
  let bits19_12 = ((raw >> 12) & 0xffU) << 12
  let bit11 = ((raw >> 20) & 0x1U) << 11
  let bits10_1 = ((raw >> 21) & 0x3ffU) << 1
  sign_extend(bit20 | bits19_12 | bit11 | bits10_1, 21)
}

///|
fn c_imm_ci(raw : UInt) -> Int {
  sign_extend((((raw >> 12) & 0x1U) << 5) | ((raw >> 2) & 0x1fU), 6)
}

///|
// For shift instructions (c.srli, c.srai): 6-bit unsigned shift amount.
// In RV64C, bit12 is the MSB of the 6-bit shift (allows shamt 32-63).
fn c_shamt6(raw : UInt) -> Int {
  (((raw >> 12) & 0x1U) << 5 | ((raw >> 2) & 0x1fU)).to_int()
}

///|
fn c_lui_imm(raw : UInt) -> UInt {
  (sign_extend((((raw >> 12) & 0x1U) << 5) | ((raw >> 2) & 0x1fU), 6)
    .reinterpret_as_uint()) <<
  12
}

///|
fn c_imm_cj(raw : UInt) -> Int {
  let imm = (((raw >> 12) & 0x1U) << 11) |
    (((raw >> 11) & 0x1U) << 4) |
    (((raw >> 9) & 0x3U) << 8) |
    (((raw >> 8) & 0x1U) << 10) |
    (((raw >> 7) & 0x1U) << 6) |
    (((raw >> 6) & 0x1U) << 7) |
    (((raw >> 3) & 0x7U) << 1) |
    (((raw >> 2) & 0x1U) << 5)
  sign_extend(imm, 12)
}

///|
fn c_imm_cb(raw : UInt) -> Int {
  let imm = (((raw >> 12) & 0x1U) << 8) |
    (((raw >> 10) & 0x3U) << 3) |
    (((raw >> 5) & 0x3U) << 6) |
    (((raw >> 3) & 0x3U) << 1) |
    (((raw >> 2) & 0x1U) << 5)
  sign_extend(imm, 9)
}

///|
fn c_uimm_lw_sw(raw : UInt) -> Int {
  ((((raw >> 10) & 0x7U) << 3) |
  (((raw >> 6) & 0x1U) << 2) |
  (((raw >> 5) & 0x1U) << 6)).reinterpret_as_int()
}

///|
fn c_nzuimm_addi4spn(raw : UInt) -> Int {
  ((((raw >> 12) & 0x1U) << 5) |
  (((raw >> 11) & 0x1U) << 4) |
  (((raw >> 10) & 0x1U) << 9) |
  (((raw >> 9) & 0x1U) << 8) |
  (((raw >> 8) & 0x1U) << 7) |
  (((raw >> 7) & 0x1U) << 6) |
  (((raw >> 6) & 0x1U) << 2) |
  (((raw >> 5) & 0x1U) << 3)).reinterpret_as_int()
}

///|
fn c_nzimm_addi16sp(raw : UInt) -> Int {
  let imm = (((raw >> 12) & 0x1U) << 9) |
    (((raw >> 4) & 0x1U) << 8) |
    (((raw >> 3) & 0x1U) << 7) |
    (((raw >> 5) & 0x1U) << 6) |
    (((raw >> 2) & 0x1U) << 5) |
    (((raw >> 6) & 0x1U) << 4)
  sign_extend(imm, 10)
}

///|
fn c_uimm_lwsp(raw : UInt) -> Int {
  ((((raw >> 2) & 0x3U) << 6) |
  (((raw >> 4) & 0x7U) << 2) |
  (((raw >> 12) & 0x1U) << 5)).reinterpret_as_int()
}

///|
fn c_uimm_swsp(raw : UInt) -> Int {
  ((((raw >> 7) & 0x3U) << 6) |
  (((raw >> 9) & 0xfU) << 2)).reinterpret_as_int()
}

///|
fn c_uimm_ld_sd(raw : UInt) -> Int {
  // C.LD/C.SD: uimm[5:3|7:6] — doubleword offset
  ((((raw >> 10) & 0x7U) << 3) |
  (((raw >> 5) & 0x3U) << 6)).reinterpret_as_int()
}

///|
fn c_uimm_ldsp(raw : UInt) -> Int {
  // C.LDSP: uimm[5|4:3|8:6]
  ((((raw >> 2) & 0x7U) << 6) |
  (((raw >> 5) & 0x3U) << 3) |
  (((raw >> 12) & 0x1U) << 5)).reinterpret_as_int()
}

///|
fn c_uimm_sdsp(raw : UInt) -> Int {
  // C.SDSP: uimm[5:3|8:6]
  ((((raw >> 7) & 0x7U) << 6) |
  (((raw >> 10) & 0x7U) << 3)).reinterpret_as_int()
}

///|
fn c_funct2_cb(raw : UInt) -> UInt {
  (raw >> 10) & 0x3U
}

///|
fn c_funct2_ca(raw : UInt) -> UInt {
  (raw >> 5) & 0x3U
}

///|
fn int_to_uint64_bits(value : Int) -> UInt64 {
  value.to_int64().reinterpret_as_uint64()
}

///|
fn low32(value : UInt64) -> UInt {
  value.to_uint()
}

///|
fn as_signed_64(value : UInt64) -> Int64 {
  value.reinterpret_as_int64()
}

///|
fn sign_extend_to_32(value : UInt64, bits : Int) -> UInt64 {
  sign_extend(low32(value), bits).to_int64().reinterpret_as_uint64()
}

///|
fn sign_extend_64(value : UInt64, bits : Int) -> UInt64 {
  if bits >= 64 {
    value
  } else {
    let shift = 64 - bits
    ((value << shift).reinterpret_as_int64() >> shift).reinterpret_as_uint64()
  }
}

///|
fn shift_mask_32(value : UInt64) -> Int {
  low32(value).reinterpret_as_int() & 0x1f
}

///|
fn shift_mask_64(value : UInt64) -> Int {
  (value & 0x3fU.to_uint64()).reinterpret_as_int64().to_int()
}

///|
fn arithmetic_shift_right_32(value : UInt64, shamt : Int) -> UInt64 {
  let signed = sign_extend_to_32(value, 32).reinterpret_as_int64()
  (signed >> shamt).reinterpret_as_uint64()
}

///|
fn arithmetic_shift_right_64(value : UInt64, shamt : Int) -> UInt64 {
  (as_signed_64(value) >> shamt).reinterpret_as_uint64()
}

///|
fn compare_signed_32(lhs : UInt64, rhs : UInt64) -> Int {
  let left = sign_extend_to_32(lhs, 32).reinterpret_as_int64()
  let right = sign_extend_to_32(rhs, 32).reinterpret_as_int64()
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_unsigned_32(lhs : UInt64, rhs : UInt64) -> Int {
  let left = low32(lhs)
  let right = low32(rhs)
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_signed_64(lhs : UInt64, rhs : UInt64) -> Int {
  let left = as_signed_64(lhs)
  let right = as_signed_64(rhs)
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_unsigned_64(lhs : UInt64, rhs : UInt64) -> Int {
  if lhs < rhs {
    -1
  } else if lhs > rhs {
    1
  } else {
    0
  }
}

///|
fn high_word_u64(value : UInt64) -> UInt64 {
  value >> 32
}

///|
fn mulh_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  high_word_u64(
    (sign_extend_to_32(lhs, 32).reinterpret_as_int64() *
    sign_extend_to_32(rhs, 32).reinterpret_as_int64()).reinterpret_as_uint64(),
  )
}

///|
fn mulhsu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  high_word_u64(
    (sign_extend_to_32(lhs, 32).reinterpret_as_int64() *
    low32(rhs).to_uint64().reinterpret_as_int64()).reinterpret_as_uint64(),
  )
}

///|
fn mulhu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  high_word_u64(low32(lhs).to_uint64() * low32(rhs).to_uint64())
}

///|
fn mulhu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let lhs_low = lhs & 0xffffffffU.to_uint64()
  let lhs_high = lhs >> 32
  let rhs_low = rhs & 0xffffffffU.to_uint64()
  let rhs_high = rhs >> 32
  let ll = lhs_low * rhs_low
  let lh = lhs_low * rhs_high
  let hl = lhs_high * rhs_low
  let hh = lhs_high * rhs_high
  hh + (lh >> 32) + (hl >> 32) + (((ll >> 32) + (lh & 0xffffffffU.to_uint64()) + (hl & 0xffffffffU.to_uint64())) >> 32)
}

///|
fn mulh_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let mut high = mulhu_64(lhs, rhs)
  if as_signed_64(lhs) < 0L {
    high = high - rhs
  }
  if as_signed_64(rhs) < 0L {
    high = high - lhs
  }
  high
}

///|
fn mulhsu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let mut high = mulhu_64(lhs, rhs)
  if as_signed_64(lhs) < 0L {
    high = high - rhs
  }
  high
}

///|
fn div_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = sign_extend_to_32(lhs, 32).reinterpret_as_int64()
  let divisor = sign_extend_to_32(rhs, 32).reinterpret_as_int64()
  let int_min = 0x80000000U.reinterpret_as_int()
  if divisor == 0 {
    0xffffffffU.to_uint64()
  } else if dividend == int_min.to_int64() && divisor == -1L {
    low32(lhs).to_uint64()
  } else {
    (dividend / divisor).reinterpret_as_uint64()
  }
}

///|
fn divu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let left = low32(lhs).to_uint64()
  let right = low32(rhs).to_uint64()
  if right == 0U.to_uint64() {
    0xffffffffU.to_uint64()
  } else {
    left / right
  }
}

///|
fn rem_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = sign_extend_to_32(lhs, 32).reinterpret_as_int64()
  let divisor = sign_extend_to_32(rhs, 32).reinterpret_as_int64()
  let int_min = 0x80000000U.reinterpret_as_int()
  if divisor == 0 {
    low32(lhs).to_uint64()
  } else if dividend == int_min.to_int64() && divisor == -1L {
    0U.to_uint64()
  } else {
    (dividend % divisor).reinterpret_as_uint64()
  }
}

///|
fn remu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let left = low32(lhs).to_uint64()
  let right = low32(rhs).to_uint64()
  if right == 0U.to_uint64() {
    left
  } else {
    left % right
  }
}

///|
fn div_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = as_signed_64(lhs)
  let divisor = as_signed_64(rhs)
  if divisor == 0L {
    bit_not(0U.to_uint64())
  } else if dividend == (1U.to_uint64() << 63).reinterpret_as_int64() && divisor == -1L {
    lhs
  } else {
    (dividend / divisor).reinterpret_as_uint64()
  }
}

///|
fn divu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  if rhs == 0U.to_uint64() {
    bit_not(0U.to_uint64())
  } else {
    lhs / rhs
  }
}

///|
fn rem_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = as_signed_64(lhs)
  let divisor = as_signed_64(rhs)
  if divisor == 0L {
    lhs
  } else if dividend == (1U.to_uint64() << 63).reinterpret_as_int64() && divisor == -1L {
    0U.to_uint64()
  } else {
    (dividend % divisor).reinterpret_as_uint64()
  }
}

///|
fn remu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  if rhs == 0U.to_uint64() {
    lhs
  } else {
    lhs % rhs
  }
}

///|
fn xlen_shift_mask(value : UInt64, xlen : Int) -> Int {
  match xlen {
    XLEN_32 => shift_mask_32(value)
    XLEN_64 => shift_mask_64(value)
    _ => abort("unsupported xlen for shift mask")
  }
}

///|
fn xlen_sign_extend(value : UInt64, bits : Int, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => sign_extend_to_32(value, bits)
    XLEN_64 => sign_extend_64(value, bits)
    _ => abort("unsupported xlen for sign extension")
  }
}

///|
fn xlen_load_sign_extend(value : UInt64, bits : Int, xlen : Int) -> UInt64 {
  match bits {
    8 => xlen_sign_extend(value, 8, xlen)
    16 => xlen_sign_extend(value, 16, xlen)
    32 => xlen_sign_extend(value, 32, xlen)
    _ => abort("unsupported load sign extension width")
  }
}

///|
fn xlen_arithmetic_shift_right(value : UInt64, shamt : Int, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => arithmetic_shift_right_32(value, shamt)
    XLEN_64 => arithmetic_shift_right_64(value, shamt)
    _ => abort("unsupported xlen for arithmetic shift")
  }
}

///|
fn xlen_compare_signed(lhs : UInt64, rhs : UInt64, xlen : Int) -> Int {
  match xlen {
    XLEN_32 => compare_signed_32(lhs, rhs)
    XLEN_64 => compare_signed_64(lhs, rhs)
    _ => abort("unsupported xlen for signed compare")
  }
}

///|
fn xlen_compare_unsigned(lhs : UInt64, rhs : UInt64, xlen : Int) -> Int {
  match xlen {
    XLEN_32 => compare_unsigned_32(lhs, rhs)
    XLEN_64 => compare_unsigned_64(lhs, rhs)
    _ => abort("unsupported xlen for unsigned compare")
  }
}

///|
fn xlen_mulh(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => mulh_32(lhs, rhs)
    XLEN_64 => mulh_64(lhs, rhs)
    _ => abort("unsupported xlen for mulh")
  }
}

///|
fn xlen_mulhsu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => mulhsu_32(lhs, rhs)
    XLEN_64 => mulhsu_64(lhs, rhs)
    _ => abort("unsupported xlen for mulhsu")
  }
}

///|
fn xlen_mulhu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => mulhu_32(lhs, rhs)
    XLEN_64 => mulhu_64(lhs, rhs)
    _ => abort("unsupported xlen for mulhu")
  }
}

///|
fn xlen_div(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => div_32(lhs, rhs)
    XLEN_64 => div_64(lhs, rhs)
    _ => abort("unsupported xlen for div")
  }
}

///|
fn xlen_divu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => divu_32(lhs, rhs)
    XLEN_64 => divu_64(lhs, rhs)
    _ => abort("unsupported xlen for divu")
  }
}

///|
fn xlen_rem(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => rem_32(lhs, rhs)
    XLEN_64 => rem_64(lhs, rhs)
    _ => abort("unsupported xlen for rem")
  }
}

///|
fn xlen_remu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => remu_32(lhs, rhs)
    XLEN_64 => remu_64(lhs, rhs)
    _ => abort("unsupported xlen for remu")
  }
}

///|
fn bool_to_reg(value : Bool) -> UInt64 {
  if value {
    1U.to_uint64()
  } else {
    0U.to_uint64()
  }
}

///|
fn trap_cause_code(cause : TrapCause) -> UInt64 {
  // Interrupt bit: bit 63 set for interrupts
  let irq_bit : UInt64 = 1U.to_uint64() << 63
  match cause {
    InstructionAccessFault => 1U.to_uint64()
    IllegalInstruction => 2U.to_uint64()
    LoadAccessFault => 5U.to_uint64()
    StoreAccessFault => 7U.to_uint64()
    InstructionPageFault => 12U.to_uint64()
    LoadPageFault => 13U.to_uint64()
    StorePageFault => 15U.to_uint64()
    EnvironmentCallFromUMode => 8U.to_uint64()
    EnvironmentCallFromSMode => 9U.to_uint64()
    EnvironmentCallFromMMode => 11U.to_uint64()
    // Interrupts — bit 63 set, code in [62:0]
    SupervisorSoftwareInterrupt => irq_bit | 1U.to_uint64()
    MachineSoftwareInterrupt => irq_bit | 3U.to_uint64()
    SupervisorTimerInterrupt => irq_bit | 5U.to_uint64()
    MachineTimerInterrupt => irq_bit | 7U.to_uint64()
    SupervisorExternalInterrupt => irq_bit | 9U.to_uint64()
    MachineExternalInterrupt => irq_bit | 11U.to_uint64()
  }
}

///|
fn privilege_mode_from_code(code : UInt64) -> PrivilegeMode {
  if code == 1U.to_uint64() {
    Supervisor
  } else if code == 3U.to_uint64() {
    Machine
  } else {
    User
  }
}

///|
fn bit_not(value : UInt64) -> UInt64 {
  value ^ (-1L).reinterpret_as_uint64()
}

///|
fn mstatus_mie(value : UInt64) -> Bool {
  (value & MSTATUS_MIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_sie(value : UInt64) -> Bool {
  (value & MSTATUS_SIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_mpie(value : UInt64) -> Bool {
  (value & MSTATUS_MPIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_spie(value : UInt64) -> Bool {
  (value & MSTATUS_SPIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_spp(value : UInt64) -> PrivilegeMode {
  if (value & MSTATUS_SPP_BIT.to_uint64()) != 0U.to_uint64() {
    Supervisor
  } else {
    User
  }
}

fn mstatus_mpp(value : UInt64) -> PrivilegeMode {
  privilege_mode_from_code((value & MSTATUS_MPP_MASK.to_uint64()) >> MSTATUS_MPP_SHIFT)
}

///|
fn set_mstatus_mie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_MIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_MIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_sie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_SIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_SIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_mpie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_MPIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_MPIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_spie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_SPIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_SPIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_spp(value : UInt64, mode : PrivilegeMode) -> UInt64 {
  match mode {
    Supervisor => value | MSTATUS_SPP_BIT.to_uint64()
    _ => value & bit_not(MSTATUS_SPP_BIT.to_uint64())
  }
}

///|
fn set_mstatus_mpp(value : UInt64, mode : PrivilegeMode) -> UInt64 {
  let mode_bits = match mode {
    User => 0U.to_uint64()
    Supervisor => 1U.to_uint64()
    Machine => 3U.to_uint64()
  }
  (value & bit_not(MSTATUS_MPP_MASK.to_uint64())) |
  ((mode_bits << MSTATUS_MPP_SHIFT) & MSTATUS_MPP_MASK.to_uint64())
}

///|
fn mstatus_after_mret(mstatus : UInt64) -> UInt64 {
  set_mstatus_mpie(
    set_mstatus_mie(set_mstatus_mpp(mstatus, User), mstatus_mpie(mstatus)),
    true,
  )
}

///|
fn mstatus_after_sret(mstatus : UInt64) -> UInt64 {
  set_mstatus_spp(
    set_mstatus_spie(set_mstatus_sie(mstatus, mstatus_spie(mstatus)), true),
    User,
  )
}

///|
// Modeled machine CSRs participate in current machine-state semantics.
// Compatibility-only storage CSRs are kept writable for upstream env/p startup.
fn is_modeled_machine_csr(csr : Int) -> Bool {
  match csr {
    CSR_MSTATUS => true
    CSR_MIE => true
    CSR_MIP => true
    CSR_MTVEC => true
    CSR_MEPC => true
    CSR_MCAUSE => true
    CSR_MTVAL => true
    CSR_MSCRATCH => true
    CSR_MISA => true
    CSR_MHARTID => true
    CSR_MVENDORID => true
    CSR_MARCHID => true
    CSR_MIMPID => true
    _ => false
  }
}

///|
fn is_modeled_supervisor_csr(csr : Int) -> Bool {
  match csr {
    CSR_SSTATUS => true
    CSR_SIE => true
    CSR_SIP => true
    CSR_STVEC => true
    CSR_SSCRATCH => true
    CSR_SEPC => true
    CSR_SCAUSE => true
    CSR_STVAL => true
    _ => false
  }
}

///|
fn is_compatibility_storage_csr(csr : Int) -> Bool {
  match csr {
    CSR_SATP => true
    CSR_MEDELEG => true
    CSR_MIDELEG => true
    CSR_PMPCFG0 => true
    CSR_PMPADDR0 => true
    CSR_MNSTATUS => true
    CSR_MCOUNTEREN => true
    CSR_SCOUNTEREN => true
    CSR_MENVCFG => true
    CSR_SENVCFG => true
    _ => false
  }
}

///|
fn is_read_only_csr(csr : Int) -> Bool {
  match csr {
    CSR_MISA => true
    CSR_MHARTID => true
    CSR_MVENDORID => true
    CSR_MARCHID => true
    CSR_MIMPID => true
    _ => false
  }
}

///|
fn is_supported_rw_csr(csr : Int) -> Bool {
  (is_modeled_machine_csr(csr) && !is_read_only_csr(csr)) ||
  is_modeled_supervisor_csr(csr) ||
  is_compatibility_storage_csr(csr)
}

///|
fn is_supported_csr(csr : Int) -> Bool {
  is_supported_rw_csr(csr) || is_read_only_csr(csr)
}

///|
fn instruction_supported_in_xlen(
  instruction : Instruction,
  xlen : Int,
  length : Int,
) -> Bool {
  match instruction {
    Addiw(_, _, _) => xlen == XLEN_64
    Slliw(_, _, _) => xlen == XLEN_64
    Srliw(_, _, _) => xlen == XLEN_64
    Sraiw(_, _, _) => xlen == XLEN_64
    Addw(_, _, _) => xlen == XLEN_64
    Subw(_, _, _) => xlen == XLEN_64
    Mulw(_, _, _) => xlen == XLEN_64
    Divw(_, _, _) => xlen == XLEN_64
    Divuw(_, _, _) => xlen == XLEN_64
    Remw(_, _, _) => xlen == XLEN_64
    Remuw(_, _, _) => xlen == XLEN_64
    Sllw(_, _, _) => xlen == XLEN_64
    Srlw(_, _, _) => xlen == XLEN_64
    Sraw(_, _, _) => xlen == XLEN_64
    Lwu(_, _, _) => xlen == XLEN_64
    Ld(_, _, _) => xlen == XLEN_64
    Sd(_, _, _) => xlen == XLEN_64
    AmoD(_, _, _, _) => xlen == XLEN_64
    // C.JAL exists only on RV32C; the 32-bit JAL x1 form remains legal on both widths.
    Jal(rd, _) => !(length == 2 && rd == 1 && xlen == XLEN_64)
    _ => true
  }
}

///|
pub fn decode(raw : UInt) -> Instruction {
  match raw & 0x7fU {
    0x0fU =>
      match funct3(raw) {
        0x0U => Fence
        0x1U => FenceI
        _ => Unknown(raw)
      }
    0x37U => Lui(rd(raw), imm_u(raw))
    0x17U => Auipc(rd(raw), imm_u(raw))
    0x13U =>
      match funct3(raw) {
        0x0U => Addi(rd(raw), rs1(raw), imm_i(raw))
        0x1U => Slli(rd(raw), rs1(raw), shamt_i(raw))
        0x2U => Slti(rd(raw), rs1(raw), imm_i(raw))
        0x3U => Sltiu(rd(raw), rs1(raw), imm_i(raw))
        0x4U => Xori(rd(raw), rs1(raw), imm_i(raw))
        0x6U => Ori(rd(raw), rs1(raw), imm_i(raw))
        0x7U => Andi(rd(raw), rs1(raw), imm_i(raw))
        0x5U =>
          match funct6(raw) {
            0x00U => Srli(rd(raw), rs1(raw), shamt_i(raw))
            0x10U => Srai(rd(raw), rs1(raw), shamt_i(raw))
            _ => Unknown(raw)
          }
        _ => Unknown(raw)
      }
    0x1bU =>
      match funct3(raw) {
        0x0U => Addiw(rd(raw), rs1(raw), imm_i(raw))
        0x1U =>
          match funct7(raw) {
            0x00U => Slliw(rd(raw), rs1(raw), shamt_iw(raw))
            _ => Unknown(raw)
          }
        0x5U =>
          match funct7(raw) {
            0x00U => Srliw(rd(raw), rs1(raw), shamt_iw(raw))
            0x20U => Sraiw(rd(raw), rs1(raw), shamt_iw(raw))
            _ => Unknown(raw)
          }
        _ => Unknown(raw)
      }
    0x33U =>
      match (funct3(raw), funct7(raw)) {
        (0x0U, 0x00U) => Add(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x20U) => Sub(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x01U) => Mul(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x00U) => Sll(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x01U) => Mulh(rd(raw), rs1(raw), rs2(raw))
        (0x2U, 0x00U) => Slt(rd(raw), rs1(raw), rs2(raw))
        (0x2U, 0x01U) => Mulhsu(rd(raw), rs1(raw), rs2(raw))
        (0x3U, 0x00U) => Sltu(rd(raw), rs1(raw), rs2(raw))
        (0x3U, 0x01U) => Mulhu(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x00U) => Xor(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x01U) => Div(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x00U) => Srl(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x20U) => Sra(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x01U) => Divu(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x00U) => Or(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x01U) => Rem(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x00U) => And(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x01U) => Remu(rd(raw), rs1(raw), rs2(raw))
        _ => Unknown(raw)
      }
    0x3bU =>
      match (funct3(raw), funct7(raw)) {
        (0x0U, 0x00U) => Addw(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x20U) => Subw(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x01U) => Mulw(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x00U) => Sllw(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x01U) => Divw(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x00U) => Srlw(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x20U) => Sraw(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x01U) => Divuw(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x01U) => Remw(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x01U) => Remuw(rd(raw), rs1(raw), rs2(raw))
        _ => Unknown(raw)
      }
    0x63U =>
      match funct3(raw) {
        0x0U => Beq(rs1(raw), rs2(raw), imm_b(raw))
        0x1U => Bne(rs1(raw), rs2(raw), imm_b(raw))
        0x4U => Blt(rs1(raw), rs2(raw), imm_b(raw))
        0x5U => Bge(rs1(raw), rs2(raw), imm_b(raw))
        0x6U => Bltu(rs1(raw), rs2(raw), imm_b(raw))
        0x7U => Bgeu(rs1(raw), rs2(raw), imm_b(raw))
        _ => Unknown(raw)
      }
    0x03U =>
      match funct3(raw) {
        0x0U => Lb(rd(raw), rs1(raw), imm_i(raw))
        0x1U => Lh(rd(raw), rs1(raw), imm_i(raw))
        0x2U => Lw(rd(raw), rs1(raw), imm_i(raw))
        0x3U => Ld(rd(raw), rs1(raw), imm_i(raw))
        0x4U => Lbu(rd(raw), rs1(raw), imm_i(raw))
        0x5U => Lhu(rd(raw), rs1(raw), imm_i(raw))
        0x6U => Lwu(rd(raw), rs1(raw), imm_i(raw))
        _ => Unknown(raw)
      }
    0x23U =>
      match funct3(raw) {
        0x0U => Sb(rs1(raw), rs2(raw), imm_s(raw))
        0x1U => Sh(rs1(raw), rs2(raw), imm_s(raw))
        0x2U => Sw(rs1(raw), rs2(raw), imm_s(raw))
        0x3U => Sd(rs1(raw), rs2(raw), imm_s(raw))
        _ => Unknown(raw)
      }
    0x6fU => Jal(rd(raw), imm_j(raw))
    0x67U =>
      match funct3(raw) {
        0x0U => Jalr(rd(raw), rs1(raw), imm_i(raw))
        _ => Unknown(raw)
      }
    0x73U =>
      match funct3(raw) {
        0x0U =>
          if funct7(raw) == 0x09U && rd(raw) == 0 {
            SfenceVma(rs1(raw), rs2(raw))
          } else {
            match csr_addr(raw) {
              0x000 => Ecall
              0x302 => Mret
              0x102 => Sret
              0x105 => Wfi
              _ => Unknown(raw)
            }
          }
        0x1U => Csrrw(rd(raw), csr_addr(raw), rs1(raw))
        0x2U => Csrrs(rd(raw), csr_addr(raw), rs1(raw))
        0x3U => Csrrc(rd(raw), csr_addr(raw), rs1(raw))
        0x5U => Csrrwi(rd(raw), csr_addr(raw), csr_uimm(raw))
        0x6U => Csrrsi(rd(raw), csr_addr(raw), csr_uimm(raw))
        0x7U => Csrrci(rd(raw), csr_addr(raw), csr_uimm(raw))
        _ => Unknown(raw)
      }
    0x2fU =>
      match funct3(raw) {
        0x2U => AmoW(funct5(raw), rd(raw), rs1(raw), rs2(raw))
        0x3U => AmoD(funct5(raw), rd(raw), rs1(raw), rs2(raw))
        _ => Unknown(raw)
      }
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q0(raw : UInt, xlen : Int) -> Instruction {
  match c_funct3(raw) {
    0x0U => {
      let imm = c_nzuimm_addi4spn(raw)
      if imm == 0 {
        Unknown(raw)
      } else {
        Addi(c_rd_prime(raw), 2, imm)
      }
    }
    0x2U => Lw(c_rd_prime(raw), c_rs1_prime(raw), c_uimm_lw_sw(raw))
    0x3U =>
      if xlen == XLEN_64 {
        Ld(c_rd_prime(raw), c_rs1_prime(raw), c_uimm_ld_sd(raw))
      } else {
        Unknown(raw)
      }
    0x6U => Sw(c_rs1_prime(raw), c_rs2_prime(raw), c_uimm_lw_sw(raw))
    0x7U =>
      if xlen == XLEN_64 {
        Sd(c_rs1_prime(raw), c_rs2_prime(raw), c_uimm_ld_sd(raw))
      } else {
        Unknown(raw)
      }
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q1_cb(raw : UInt, xlen : Int) -> Instruction {
  let rd = c_rs1_prime(raw)
  let rs2 = c_rs2_prime(raw)
  match c_funct2_cb(raw) {
    // C.SRLI: 6-bit unsigned shift (bit12||bits[6:2]). RV64 allows shamt 32-63.
    0x0U => Srli(rd, rd, c_shamt6(raw))
    // C.SRAI: 6-bit unsigned shift. RV64 allows shamt 32-63.
    0x1U => Srai(rd, rd, c_shamt6(raw))
    0x2U => Andi(rd, rd, c_imm_ci(raw))
    0x3U =>
      if ((raw >> 12) & 0x1U) != 0U {
        if xlen == XLEN_64 {
          match c_funct2_ca(raw) {
            0x0U => Subw(rd, rd, rs2)
            0x1U => Addw(rd, rd, rs2)
            _ => Unknown(raw)
          }
        } else {
          Unknown(raw)
        }
      } else {
        match c_funct2_ca(raw) {
          0x0U => Sub(rd, rd, rs2)
          0x1U => Xor(rd, rd, rs2)
          0x2U => Or(rd, rd, rs2)
          0x3U => And(rd, rd, rs2)
          _ => Unknown(raw)
        }
      }
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q1(raw : UInt, xlen : Int) -> Instruction {
  match c_funct3(raw) {
    0x0U => Addi(c_rd_rs1(raw), c_rd_rs1(raw), c_imm_ci(raw))
    0x1U =>
      if xlen == XLEN_64 {
        Addiw(c_rd_rs1(raw), c_rd_rs1(raw), c_imm_ci(raw))
      } else {
        Jal(1, c_imm_cj(raw))
      }
    0x2U => Addi(c_rd_rs1(raw), 0, c_imm_ci(raw))
    0x3U => {
      let rd = c_rd_rs1(raw)
      if rd == 2 {
        let imm = c_nzimm_addi16sp(raw)
        if imm == 0 {
          Unknown(raw)
        } else {
          Addi(2, 2, imm)
        }
      } else {
        let imm = c_imm_ci(raw)
        if rd == 0 || imm == 0 {
          Unknown(raw)
        } else {
          Lui(rd, c_lui_imm(raw))
        }
      }
    }
    0x4U => decode_c_q1_cb(raw, xlen)
    0x5U => Jal(0, c_imm_cj(raw))
    0x6U => Beq(c_rs1_prime(raw), 0, c_imm_cb(raw))
    0x7U => Bne(c_rs1_prime(raw), 0, c_imm_cb(raw))
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q2_cr(raw : UInt) -> Instruction {
  let rd = c_rd_rs1(raw)
  let rs2 = c_rs2(raw)
  if ((raw >> 12) & 0x1U) == 0U {
    if rs2 == 0 {
      if rd == 0 { Unknown(raw) } else { Jalr(0, rd, 0) }
    } else {
      Add(rd, 0, rs2)
    }
  } else {
    if rs2 == 0 {
      if rd == 0 { Unknown(raw) } else { Jalr(1, rd, 0) }
    } else {
      Add(rd, rd, rs2)
    }
  }
}

///|
fn decode_c_q2(raw : UInt, xlen : Int) -> Instruction {
  ignore(xlen)
  match c_funct3(raw) {
    0x0U => {
      let rd = c_rd_rs1(raw)
      if rd == 0 {
        Unknown(raw)
      } else {
        Slli(rd, rd, c_imm_ci(raw))
      }
    }
    0x2U => {
      let rd = c_rd_rs1(raw)
      if rd == 0 {
        Unknown(raw)
      } else {
        Lw(rd, 2, c_uimm_lwsp(raw))
      }
    }
    0x3U => {
      let rd = c_rd_rs1(raw)
      if rd == 0 {
        Unknown(raw)
      } else {
        Ld(rd, 2, c_uimm_ldsp(raw))
      }
    }
    0x4U => decode_c_q2_cr(raw)
    0x6U => Sw(2, c_rs2(raw), c_uimm_swsp(raw))
    0x7U => Sd(2, c_rs2(raw), c_uimm_sdsp(raw))
    _ => Unknown(raw)
  }
}

///|
fn decode_compressed(raw : UInt, xlen : Int) -> Instruction {
  match raw & 0x3U {
    0x0U => decode_c_q0(raw, xlen)
    0x1U => decode_c_q1(raw, xlen)
    0x2U => decode_c_q2(raw, xlen)
    _ => Unknown(raw)
  }
}

