fn Runner::xlen_bits(self : Runner) -> Int {
  match self.config.xlen {
    Xlen32 => XLEN_32
    Xlen64 => XLEN_64
  }
}

///|
fn Runner::mask_value_to_xlen(self : Runner, value : UInt64) -> UInt64 {
  value & xlen_mask(self.xlen_bits())
}

///|
fn Runner::write_xlen_reg(self : Runner, rd : Int, value : UInt64) -> Unit {
  self.cpu.write_reg(rd, self.mask_value_to_xlen(value))
}

///|
fn Runner::write_word_reg(self : Runner, rd : Int, value : UInt64) -> Unit {
  match self.xlen_bits() {
    XLEN_32 => self.write_xlen_reg(rd, value)
    XLEN_64 => self.write_xlen_reg(rd, sign_extend_64(value & 0xffffffffU.to_uint64(), 32))
    _ => abort("unsupported xlen for word writeback")
  }
}

///|
fn Runner::fp_has_d(self : Runner) -> Bool {
  (self.config.extensions & MISA_EXT_D) != 0U.to_uint64()
}

///|
fn Runner::write_freg_single_bits(self : Runner, rd : Int, value : UInt) -> Unit {
  let stored =
    if self.fp_has_d() {
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
  if self.fp_has_d() && (slot >> 32) != 0xffffffffU.to_uint64() {
    f32_canonical_nan_bits()
  } else {
    low32(slot)
  }
}

///|
fn Runner::write_freg_double_bits(self : Runner, rd : Int, value : UInt64) -> Unit {
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
  (bits & exponent_mask) == exponent_mask && (bits & fraction_mask) != 0U.to_uint64()
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
    if f32_sign_bit(lhs) || f32_sign_bit(rhs) { 0x80000000U } else { 0U }
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
    if f64_sign_bit(lhs) || f64_sign_bit(rhs) { 1U.to_uint64() << 63 } else { 0U.to_uint64() }
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
fn Runner::step_next_pc(self : Runner, delta : Int) -> UInt64 {
  self.cpu.pc + int_to_uint64_bits(delta)
}

///|
pub(all) enum AccessType {
  Fetch
  Load
  Store
}

///|
pub(all) enum TranslateResult {
  TranslatedAddr(UInt64)
  TranslateFault(TrapCause)
}

///|
pub fn access_type_fault(access_type : AccessType) -> TrapCause {
  match access_type {
    Fetch => InstructionPageFault
    Load => LoadPageFault
    Store => StorePageFault
  }
}

fn Runner::execute_op_imm(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Addi(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) + int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Addiw(rd, rs1, imm) => {
      self.write_word_reg(rd, self.cpu.read_reg(rs1) + int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Slti(rd, rs1, imm) => {
      self.write_xlen_reg(
        rd,
        bool_to_reg(xlen_compare_signed(self.cpu.read_reg(rs1), int_to_uint64_bits(imm), xlen) < 0),
      )
      self.cpu.pc = next_pc
      Running
    }
    Sltiu(rd, rs1, imm) => {
      self.write_xlen_reg(
        rd,
        bool_to_reg(
          xlen_compare_unsigned(self.cpu.read_reg(rs1), int_to_uint64_bits(imm), xlen) < 0,
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    Xori(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) ^ int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Ori(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) | int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Andi(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) & int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Slli(rd, rs1, shamt) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) << shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srli(rd, rs1, shamt) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) >> shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srai(rd, rs1, shamt) => {
      self.write_xlen_reg(
        rd,
        xlen_arithmetic_shift_right(self.cpu.read_reg(rs1), shamt, xlen),
      )
      self.cpu.pc = next_pc
      Running
    }
    Slliw(rd, rs1, shamt) => {
      self.write_word_reg(rd, self.cpu.read_reg(rs1) << shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srliw(rd, rs1, shamt) => {
      self.write_word_reg(rd, low32(self.cpu.read_reg(rs1)).to_uint64() >> shamt)
      self.cpu.pc = next_pc
      Running
    }
    Sraiw(rd, rs1, shamt) => {
      self.write_word_reg(rd, arithmetic_shift_right_32(self.cpu.read_reg(rs1), shamt))
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected op-imm dispatch")
  }
}

///|
fn Runner::execute_op(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match self.execute_op_m(instruction, next_pc) {
    Some(result) => result
    None =>
      match instruction {
        Add(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Sub(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Addw(rd, rs1, rs2) => {
          self.write_word_reg(rd, self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Subw(rd, rs1, rs2) => {
          self.write_word_reg(rd, self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Sll(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) << xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sllw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            low32(self.cpu.read_reg(rs1)).to_uint64() <<
            shift_mask_32(self.cpu.read_reg(rs2)),
          )
          self.cpu.pc = next_pc
          Running
        }
        Slt(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            bool_to_reg(
              xlen_compare_signed(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sltu(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            bool_to_reg(
              xlen_compare_unsigned(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Xor(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) ^ self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Srl(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) >> xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
        Srlw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            low32(self.cpu.read_reg(rs1)).to_uint64() >>
            shift_mask_32(self.cpu.read_reg(rs2)),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sra(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            xlen_arithmetic_shift_right(
              self.cpu.read_reg(rs1),
              xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
              xlen,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sraw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            arithmetic_shift_right_32(
              self.cpu.read_reg(rs1),
              shift_mask_32(self.cpu.read_reg(rs2)),
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Or(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) | self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        And(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) & self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        _ => abort("unexpected op dispatch")
      }
  }
}

///|
fn Runner::execute_op_m(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult? {
  let xlen = self.xlen_bits()
  match instruction {
    Mul(rd, rs1, rs2) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) * self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulw(rd, rs1, rs2) => {
      self.write_word_reg(rd, low32(self.cpu.read_reg(rs1)).to_uint64() * low32(self.cpu.read_reg(rs2)).to_uint64())
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulh(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_mulh(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulhsu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_mulhsu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulhu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_mulhu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Div(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_div(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Divw(rd, rs1, rs2) => {
      self.write_word_reg(rd, div_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Divu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_divu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Divuw(rd, rs1, rs2) => {
      self.write_word_reg(rd, divu_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Rem(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_rem(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Remw(rd, rs1, rs2) => {
      self.write_word_reg(rd, rem_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Remu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_remu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Remuw(rd, rs1, rs2) => {
      self.write_word_reg(rd, remu_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    _ => None
  }
}

///|
fn Runner::execute_branch(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Beq(rs1, rs2, imm) => {
      self.cpu.pc = if self.cpu.read_reg(rs1) == self.cpu.read_reg(rs2) {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bne(rs1, rs2, imm) => {
      self.cpu.pc = if self.cpu.read_reg(rs1) != self.cpu.read_reg(rs2) {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Blt(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_signed(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bge(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_signed(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) >= 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bltu(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_unsigned(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bgeu(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_unsigned(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) >= 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    _ => abort("unexpected branch dispatch")
  }
}

///|
fn Runner::load_and_write(
  self : Runner,
  rs1 : Int,
  imm : Int,
  width : Int,
  next_pc : UInt64,
  write : (UInt64) -> Unit,
) -> StepResult {
  let addr = self.address_from(rs1, imm)
  let (pa, check) = self.load_check(addr, width)
  match check {
    Some(result) => result
    None => {
      write(pa)
      self.cpu.pc = next_pc
      Running
    }
  }
}

///|
fn Runner::execute_load(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Lb(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 1, next_pc, fn(pa) {
        self.write_xlen_reg(rd, xlen_load_sign_extend(self.phy_load_u8(pa), 8, xlen))
      })
    Lh(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 2, next_pc, fn(pa) {
        self.write_xlen_reg(rd, xlen_load_sign_extend(self.phy_load_u16(pa), 16, xlen))
      })
    Lw(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 4, next_pc, fn(pa) {
        self.write_word_reg(rd, self.phy_load_u32(pa))
      })
    Lwu(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 4, next_pc, fn(pa) {
        self.write_xlen_reg(rd, self.phy_load_u32(pa))
      })
    Ld(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 8, next_pc, fn(pa) {
        self.write_xlen_reg(rd, self.phy_load_u64(pa))
      })
    Lbu(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 1, next_pc, fn(pa) {
        self.write_xlen_reg(rd, self.phy_load_u8(pa))
      })
    Lhu(rd, rs1, imm) =>
      self.load_and_write(rs1, imm, 2, next_pc, fn(pa) {
        self.write_xlen_reg(rd, self.phy_load_u16(pa))
      })
    _ => abort("unexpected load dispatch")
  }
}

///|
fn Runner::store_and_commit(
  self : Runner,
  rs1 : Int,
  imm : Int,
  width : Int,
  next_pc : UInt64,
  store : (UInt64) -> Unit,
) -> StepResult {
  let addr = self.address_from(rs1, imm)
  let (pa, check) = self.store_check(addr, width)
  match check {
    Some(result) => result
    None => {
      store(pa)
      self.cpu.pc = next_pc
      Running
    }
  }
}

///|
fn Runner::execute_store(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Sb(rs1, rs2, imm) =>
      self.store_and_commit(rs1, imm, 1, next_pc, fn(pa) {
        self.phy_store_u8(pa, self.cpu.read_reg(rs2))
      })
    Sh(rs1, rs2, imm) =>
      self.store_and_commit(rs1, imm, 2, next_pc, fn(pa) {
        self.phy_store_u16(pa, self.cpu.read_reg(rs2))
      })
    Sw(rs1, rs2, imm) =>
      self.store_and_commit(rs1, imm, 4, next_pc, fn(pa) {
        self.phy_store_u32(pa, self.cpu.read_reg(rs2))
      })
    Sd(rs1, rs2, imm) =>
      self.store_and_commit(rs1, imm, 8, next_pc, fn(pa) {
        self.phy_store_u64(pa, self.cpu.read_reg(rs2))
      })
    _ => abort("unexpected store dispatch")
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
        self.phy_store_u32(pa, self.read_freg_single_transfer_bits(rs2).to_uint64())
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
      let result = f32_bits_from_host(f32_from_bits(self.read_freg_single_value_bits(rs1)) +
        f32_from_bits(self.read_freg_single_value_bits(rs2)))
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSubS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(f32_from_bits(self.read_freg_single_value_bits(rs1)) -
        f32_from_bits(self.read_freg_single_value_bits(rs2)))
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMulS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(f32_from_bits(self.read_freg_single_value_bits(rs1)) *
        f32_from_bits(self.read_freg_single_value_bits(rs2)))
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FDivS(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(f32_from_bits(self.read_freg_single_value_bits(rs1)) /
        f32_from_bits(self.read_freg_single_value_bits(rs2)))
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSqrtS(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f32_bits_from_host(f32_from_bits(self.read_freg_single_value_bits(rs1)).sqrt())
      self.write_freg_single_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMinS(rd, rs1, rs2) => {
      self.write_freg_single_bits(
        rd,
        f32_min_bits(self.read_freg_single_value_bits(rs1), self.read_freg_single_value_bits(rs2)),
      )
      self.cpu.pc = next_pc
      Running
    }
    FMaxS(rd, rs1, rs2) => {
      self.write_freg_single_bits(
        rd,
        f32_max_bits(self.read_freg_single_value_bits(rs1), self.read_freg_single_value_bits(rs2)),
      )
      self.cpu.pc = next_pc
      Running
    }
    FAddD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(f64_from_bits(self.read_freg_double_bits(rs1)) +
        f64_from_bits(self.read_freg_double_bits(rs2)))
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSubD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(f64_from_bits(self.read_freg_double_bits(rs1)) -
        f64_from_bits(self.read_freg_double_bits(rs2)))
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMulD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(f64_from_bits(self.read_freg_double_bits(rs1)) *
        f64_from_bits(self.read_freg_double_bits(rs2)))
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FDivD(rd, rs1, rs2, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(f64_from_bits(self.read_freg_double_bits(rs1)) /
        f64_from_bits(self.read_freg_double_bits(rs2)))
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FSqrtD(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = f64_bits_from_host(f64_from_bits(self.read_freg_double_bits(rs1)).sqrt())
      self.write_freg_double_bits(rd, result)
      self.cpu.pc = next_pc
      Running
    }
    FMinD(rd, rs1, rs2) => {
      self.write_freg_double_bits(
        rd,
        f64_min_bits(self.read_freg_double_bits(rs1), self.read_freg_double_bits(rs2)),
      )
      self.cpu.pc = next_pc
      Running
    }
    FMaxD(rd, rs1, rs2) => {
      self.write_freg_double_bits(
        rd,
        f64_max_bits(self.read_freg_double_bits(rs1), self.read_freg_double_bits(rs2)),
      )
      self.cpu.pc = next_pc
      Running
    }
    FCvtSD(rd, rs1, rm) => {
      if !self.fp_rounding_mode_supported(rm) {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      let result = Float::from_double(f64_from_bits(self.read_freg_double_bits(rs1)))
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

///|
fn amo_op(funct5 : UInt, old_val : UInt64, src : UInt64, xlen : Int) -> UInt64 {
  match funct5 {
    0x01U => src // AMOSWAP
    0x00U => old_val + src // AMOADD
    0x04U => old_val ^ src // AMOXOR
    0x0cU => old_val & src // AMOAND
    0x08U => old_val | src // AMOOR
    0x10U => // AMOMIN (signed)
      if xlen_compare_signed(old_val, src, xlen) <= 0 { old_val } else { src }
    0x14U => // AMOMAX (signed)
      if xlen_compare_signed(old_val, src, xlen) >= 0 { old_val } else { src }
    0x18U => // AMOMINU (unsigned)
      if xlen_compare_unsigned(old_val, src, xlen) <= 0 { old_val } else { src }
    0x1cU => // AMOMAXU (unsigned)
      if xlen_compare_unsigned(old_val, src, xlen) >= 0 { old_val } else { src }
    _ => old_val // should not happen; caller validates
  }
}

///|
fn Runner::execute_amo(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    AmoW(funct5_val, rd, rs1, rs2) => {
      let addr = self.cpu.read_reg(rs1)
      // LR.W
      if funct5_val == 0x02U {
        let (pa, check) = self.load_check(addr, 4)
        match check {
          Some(result) => return result
          None => ()
        }
        let loaded = self.phy_load_u32(pa)
        let sign_extended = xlen_sign_extend(loaded, 32, self.xlen_bits())
        self.write_xlen_reg(rd, sign_extended)
        self.cpu.pc = next_pc
        return Running
      }
      // SC.W — always succeeds on single-hart
      if funct5_val == 0x03U {
        let (pa, check) = self.store_check(addr, 4)
        match check {
          Some(result) => return result
          None => ()
        }
        self.phy_store_u32(pa, self.cpu.read_reg(rs2))
        self.write_xlen_reg(rd, 0U.to_uint64()) // 0 = success
        self.cpu.pc = next_pc
        return Running
      }
      // Other AMO.W: load-op-store
      let (pa, lcheck) = self.load_check(addr, 4)
      match lcheck {
        Some(result) => return result
        None => ()
      }
      let (spa, scheck) = self.store_check(addr, 4)
      match scheck {
        Some(result) => return result
        None => ()
      }
      let old_val = xlen_sign_extend(self.phy_load_u32(pa), 32, self.xlen_bits())
      let src = self.cpu.read_reg(rs2)
      let new_val = amo_op(funct5_val, old_val, src, self.xlen_bits())
      self.phy_store_u32(spa, new_val)
      self.write_xlen_reg(rd, old_val)
      self.cpu.pc = next_pc
      Running
    }
    AmoD(funct5_val, rd, rs1, rs2) => {
      let addr = self.cpu.read_reg(rs1)
      // LR.D
      if funct5_val == 0x02U {
        let (pa, check) = self.load_check(addr, 8)
        match check {
          Some(result) => return result
          None => ()
        }
        let loaded = self.phy_load_u64(pa)
        self.write_xlen_reg(rd, loaded)
        self.cpu.pc = next_pc
        return Running
      }
      // SC.D — always succeeds on single-hart
      if funct5_val == 0x03U {
        let (pa, check) = self.store_check(addr, 8)
        match check {
          Some(result) => return result
          None => ()
        }
        self.phy_store_u64(pa, self.cpu.read_reg(rs2))
        self.write_xlen_reg(rd, 0U.to_uint64())
        self.cpu.pc = next_pc
        return Running
      }
      // Other AMO.D: load-op-store
      let (pa, lcheck) = self.load_check(addr, 8)
      match lcheck {
        Some(result) => return result
        None => ()
      }
      let (spa, scheck) = self.store_check(addr, 8)
      match scheck {
        Some(result) => return result
        None => ()
      }
      let old_val = self.phy_load_u64(pa)
      let src = self.cpu.read_reg(rs2)
      let new_val = amo_op(funct5_val, old_val, src, self.xlen_bits())
      self.phy_store_u64(spa, new_val)
      self.write_xlen_reg(rd, old_val)
      self.cpu.pc = next_pc
      Running
    }
    _ => self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
}

///|
fn Runner::execute_jump(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Jal(rd, imm) => {
      self.write_xlen_reg(rd, next_pc)
      self.cpu.pc = self.step_next_pc(imm)
      Running
    }
    Jalr(rd, rs1, imm) => {
      let target = (self.cpu.read_reg(rs1) + int_to_uint64_bits(imm)) &
        bit_not(1U.to_uint64())
      self.write_xlen_reg(rd, next_pc)
      self.cpu.pc = target
      Running
    }
    _ => abort("unexpected jump dispatch")
  }
}

fn Runner::read_csr_visible(self : Runner, csr : Int) -> UInt64 {
  match csr {
    CSR_FFLAGS => self.read_fcsr() & FCSR_FFLAGS_MASK
    CSR_FRM => (self.read_fcsr() & FCSR_FRM_MASK) >> FCSR_FRM_SHIFT
    CSR_FCSR => self.read_fcsr()
    CSR_SSTATUS => self.cpu.read_csr(CSR_MSTATUS) & SSTATUS_VISIBLE_MASK.to_uint64()
    CSR_SIP => self.cpu.read_csr(CSR_MIP) & SIP_VISIBLE_MASK
    CSR_SIE => self.cpu.read_csr(CSR_MIE) & SIP_VISIBLE_MASK
    _ => self.cpu.read_csr(csr)
  }
}

///|
fn Runner::write_csr_visible(self : Runner, csr : Int, value : UInt64) -> Unit {
  match csr {
    CSR_FFLAGS => {
      let fcsr = self.read_fcsr()
      self.write_fcsr((fcsr & bit_not(FCSR_FFLAGS_MASK)) | (value & FCSR_FFLAGS_MASK))
    }
    CSR_FRM => {
      let fcsr = self.read_fcsr()
      let frm_bits = (value & 0x7U.to_uint64()) << FCSR_FRM_SHIFT
      self.write_fcsr((fcsr & bit_not(FCSR_FRM_MASK)) | frm_bits)
    }
    CSR_FCSR => self.write_fcsr(value)
    CSR_SSTATUS => {
      let mstatus = self.cpu.read_csr(CSR_MSTATUS)
      let next_mstatus =
        (mstatus & bit_not(SSTATUS_VISIBLE_MASK.to_uint64())) |
        (value & SSTATUS_VISIBLE_MASK.to_uint64())
      self.cpu.write_csr(CSR_MSTATUS, next_mstatus)
    }
    CSR_SIP => {
      let mip = self.cpu.read_csr(CSR_MIP)
      self.cpu.write_csr(
        CSR_MIP,
        (mip & bit_not(SIP_VISIBLE_MASK)) | (value & SIP_VISIBLE_MASK),
      )
    }
    CSR_SIE => {
      let mie = self.cpu.read_csr(CSR_MIE)
      self.cpu.write_csr(
        CSR_MIE,
        (mie & bit_not(SIP_VISIBLE_MASK)) | (value & SIP_VISIBLE_MASK),
      )
    }
    CSR_SATP => {
      // WARL: satp.MODE field. Only mode=0 (Bare) and mode=8 (Sv39) are
      // supported. If an unsupported mode is written, store mode=0 (Bare)
      // with PPN=0 instead, so the kernel's mode-probe sequence detects
      // that the requested mode is not available.
      let mode = (value >> 60) & 0xFU.to_uint64()
      let stored = if mode == 0U.to_uint64() || mode == 8U.to_uint64() {
        value
      } else {
        0U.to_uint64()
      }
      self.cpu.write_csr(CSR_SATP, stored)
    }
    _ => self.cpu.write_csr(csr, value)
  }
}

///|
fn Runner::read_csr_checked(self : Runner, csr : Int) -> UInt64? {
  if is_supported_csr(csr) {
    Some(self.read_csr_visible(csr))
  } else {
    None
  }
}

///|
fn Runner::execute_csr_read_write_checked(
  self : Runner,
  rd : Int,
  csr : Int,
  write_value : UInt64,
  should_write : Bool,
  next_pc : UInt64,
  current_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let old_value = match self.read_csr_checked(csr) {
    Some(value) => value
    None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  if should_write {
    if !is_supported_rw_csr(csr) {
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
    self.write_csr_visible(csr, write_value)
  }
  self.write_xlen_reg(rd, old_value)
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_system(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    Csrrw(rd, csr, rs1) =>
      self.execute_csr_read_write_checked(
        rd,
        csr,
        self.cpu.read_reg(rs1),
        true,
        next_pc,
        current_pc,
        raw,
      )
    Csrrs(rd, csr, rs1) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value | self.cpu.read_reg(rs1),
        rs1 != 0,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrc(rd, csr, rs1) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value & bit_not(self.cpu.read_reg(rs1)),
        rs1 != 0,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrwi(rd, csr, uimm) =>
      self.execute_csr_read_write_checked(
        rd,
        csr,
        uimm.to_uint64(),
        true,
        next_pc,
        current_pc,
        raw,
      )
    Csrrsi(rd, csr, uimm) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value | uimm.to_uint64(),
        uimm != 0U,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrci(rd, csr, uimm) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value & bit_not(uimm.to_uint64()),
        uimm != 0U,
        next_pc,
        current_pc,
        raw,
      )
    }
    SfenceVma(_, _) => {
      self.cpu.pc = next_pc
      Running
    }
    Ecall => {
      let cause = match self.cpu.privilege {
        User => EnvironmentCallFromUMode
        Supervisor => EnvironmentCallFromSMode
        Machine => EnvironmentCallFromMMode
      }
      self.raise_trap(cause, current_pc, 0U.to_uint64())
    }
    Mret => self.execute_mret()
    Sret => self.execute_sret()
    Unknown(_) => self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    _ => abort("unexpected system dispatch")
  }
}

///|
fn Runner::execute_mret(self : Runner) -> StepResult {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  self.cpu.write_csr(CSR_MSTATUS, mstatus_after_mret(mstatus))
  self.cpu.privilege = mstatus_mpp(mstatus)
  self.cpu.pc = self.cpu.read_csr(CSR_MEPC)
  Running
}

///|
fn Runner::execute_sret(self : Runner) -> StepResult {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  self.cpu.write_csr(CSR_MSTATUS, mstatus_after_sret(mstatus))
  self.cpu.privilege = mstatus_spp(mstatus)
  self.cpu.pc = self.cpu.read_csr(CSR_SEPC)
  Running
}

///|
// Interrupt priority order (high to low): MEI, MSI, MTI, SEI, SSI, STI
fn interrupt_cause_from_mip_bit(bit : Int) -> TrapCause {
  match bit {
    11 => MachineExternalInterrupt
    3  => MachineSoftwareInterrupt
    7  => MachineTimerInterrupt
    9  => SupervisorExternalInterrupt
    1  => SupervisorSoftwareInterrupt
    5  => SupervisorTimerInterrupt
    _  => MachineTimerInterrupt // fallback
  }
}

///|
// Return the highest-priority interrupt cause from a bitmap, or None.
fn highest_interrupt_cause(pending : UInt64) -> TrapCause? {
  // Priority: 11, 3, 7, 9, 1, 5
  for bit in [11, 3, 7, 9, 1, 5] {
    if ((pending >> bit) & 1U.to_uint64()) != 0U.to_uint64() {
      return Some(interrupt_cause_from_mip_bit(bit))
    }
  }
  None
}

///|
// Check for pending interrupts and deliver to the appropriate privilege mode.
// Returns Running if an interrupt was taken, None if no interrupt pending.
fn Runner::take_pending_interrupt(self : Runner) -> StepResult? {
  let mip = self.cpu.read_csr(CSR_MIP)
  let mie = self.cpu.read_csr(CSR_MIE)
  let pending = mip & mie
  if pending == 0U.to_uint64() {
    return None
  }
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let mideleg = self.cpu.read_csr(CSR_MIDELEG)
  // Machine-level interrupts: bits NOT in mideleg
  let m_pending = pending & bit_not(mideleg)
  let m_enabled = match self.cpu.privilege {
    Machine => mstatus_mie(mstatus)
    _ => true // M-mode interrupts always preempt lower-privilege modes
  }
  if m_pending != 0U.to_uint64() && m_enabled {
    match highest_interrupt_cause(m_pending) {
      Some(cause) => return Some(self.raise_trap(cause, self.cpu.pc, 0U.to_uint64()))
      None => ()
    }
  }
  // Supervisor-level interrupts: bits in mideleg
  let s_pending = pending & mideleg
  let s_enabled = match self.cpu.privilege {
    Supervisor => mstatus_sie(mstatus)
    User => true
    Machine => false // M-mode does not take S-mode interrupts
  }
  if s_pending != 0U.to_uint64() && s_enabled {
    match highest_interrupt_cause(s_pending) {
      Some(cause) => return Some(self.raise_trap(cause, self.cpu.pc, 0U.to_uint64()))
      None => ()
    }
  }
  None
}

///|
pub fn Runner::step(self : Runner) -> StepResult {
  // Advance CLINT mtime and update MIP.MTIP
  self.update_timer()
  // Deliver pending interrupts before executing next instruction
  match self.take_pending_interrupt() {
    Some(result) => return result
    None => ()
  }
  let current_pc = self.cpu.pc
  let fetch_pa = match self.translate_address(current_pc, Fetch, self.cpu.privilege) {
    TranslatedAddr(pa) => pa
    TranslateFault(cause) =>
      return self.raise_trap(cause, current_pc, current_pc)
  }
  let fetched = match self.fetch_instruction(fetch_pa) {
    Some(instruction) => instruction
    None => return self.raise_trap(InstructionAccessFault, current_pc, current_pc)
  }
  let next_pc = current_pc + fetched.length.reinterpret_as_uint().to_uint64()
  let raw = fetched.raw
  let instruction = if fetched.length == 2 {
    decode_compressed(raw, self.xlen_bits())
  } else {
    decode(raw)
  }
  if !instruction_supported_for_current_config(
    instruction,
    self.xlen_bits(),
    self.config.extensions,
    fetched.length,
  ) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  match instruction {
    Fence => {
      self.cpu.pc = next_pc
      Running
    }
    FenceI => {
      self.cpu.pc = next_pc
      Running
    }
    Lui(rd, imm) => {
      self.write_xlen_reg(rd, xlen_sign_extend(imm.to_uint64(), 32, self.xlen_bits()))
      self.cpu.pc = next_pc
      Running
    }
    Auipc(rd, imm) => {
      self.write_xlen_reg(
        rd,
        current_pc + xlen_sign_extend(imm.to_uint64(), 32, self.xlen_bits()),
      )
      self.cpu.pc = next_pc
      Running
    }
    Addi(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Addiw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slti(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Sltiu(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Xori(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Ori(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Andi(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slli(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srli(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srai(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slliw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srliw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Sraiw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Add(_, _, _) => self.execute_op(instruction, next_pc)
    Sub(_, _, _) => self.execute_op(instruction, next_pc)
    Addw(_, _, _) => self.execute_op(instruction, next_pc)
    Subw(_, _, _) => self.execute_op(instruction, next_pc)
    Mul(_, _, _) => self.execute_op(instruction, next_pc)
    Mulw(_, _, _) => self.execute_op(instruction, next_pc)
    Mulh(_, _, _) => self.execute_op(instruction, next_pc)
    Mulhsu(_, _, _) => self.execute_op(instruction, next_pc)
    Mulhu(_, _, _) => self.execute_op(instruction, next_pc)
    Div(_, _, _) => self.execute_op(instruction, next_pc)
    Divw(_, _, _) => self.execute_op(instruction, next_pc)
    Divu(_, _, _) => self.execute_op(instruction, next_pc)
    Divuw(_, _, _) => self.execute_op(instruction, next_pc)
    Rem(_, _, _) => self.execute_op(instruction, next_pc)
    Remw(_, _, _) => self.execute_op(instruction, next_pc)
    Remu(_, _, _) => self.execute_op(instruction, next_pc)
    Remuw(_, _, _) => self.execute_op(instruction, next_pc)
    Sll(_, _, _) => self.execute_op(instruction, next_pc)
    Sllw(_, _, _) => self.execute_op(instruction, next_pc)
    Slt(_, _, _) => self.execute_op(instruction, next_pc)
    Sltu(_, _, _) => self.execute_op(instruction, next_pc)
    Xor(_, _, _) => self.execute_op(instruction, next_pc)
    Srl(_, _, _) => self.execute_op(instruction, next_pc)
    Sra(_, _, _) => self.execute_op(instruction, next_pc)
    Srlw(_, _, _) => self.execute_op(instruction, next_pc)
    Sraw(_, _, _) => self.execute_op(instruction, next_pc)
    Or(_, _, _) => self.execute_op(instruction, next_pc)
    And(_, _, _) => self.execute_op(instruction, next_pc)
    Beq(_, _, _) => self.execute_branch(instruction, next_pc)
    Bne(_, _, _) => self.execute_branch(instruction, next_pc)
    Blt(_, _, _) => self.execute_branch(instruction, next_pc)
    Bge(_, _, _) => self.execute_branch(instruction, next_pc)
    Bltu(_, _, _) => self.execute_branch(instruction, next_pc)
    Bgeu(_, _, _) => self.execute_branch(instruction, next_pc)
    Lb(_, _, _) => self.execute_load(instruction, next_pc)
    Lh(_, _, _) => self.execute_load(instruction, next_pc)
    Lw(_, _, _) => self.execute_load(instruction, next_pc)
    Lwu(_, _, _) => self.execute_load(instruction, next_pc)
    Ld(_, _, _) => self.execute_load(instruction, next_pc)
    Lbu(_, _, _) => self.execute_load(instruction, next_pc)
    Lhu(_, _, _) => self.execute_load(instruction, next_pc)
    Flw(_, _, _) => self.execute_fp_load_store(instruction, next_pc)
    Fld(_, _, _) => self.execute_fp_load_store(instruction, next_pc)
    Sb(_, _, _) => self.execute_store(instruction, next_pc)
    Sh(_, _, _) => self.execute_store(instruction, next_pc)
    Sw(_, _, _) => self.execute_store(instruction, next_pc)
    Sd(_, _, _) => self.execute_store(instruction, next_pc)
    Fsw(_, _, _) => self.execute_fp_load_store(instruction, next_pc)
    Fsd(_, _, _) => self.execute_fp_load_store(instruction, next_pc)
    Jal(_, _) => self.execute_jump(instruction, next_pc)
    Jalr(_, _, _) => self.execute_jump(instruction, next_pc)
    Csrrw(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrs(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrc(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrwi(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrsi(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrci(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    SfenceVma(_, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Wfi => {
      self.cpu.pc = next_pc
      Running
    }
    AmoW(_, _, _, _) => self.execute_amo(instruction, current_pc, next_pc, raw)
    AmoD(_, _, _, _) => self.execute_amo(instruction, current_pc, next_pc, raw)
    FAddS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSubS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMulS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FDivS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSqrtS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMinS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMaxS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FAddD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSubD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMulD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FDivD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSqrtD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMinD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMaxD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvXW(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvWX(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvXD(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvDX(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtSD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtDS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    Ecall => self.execute_system(instruction, current_pc, next_pc, raw)
    Mret => self.execute_system(instruction, current_pc, next_pc, raw)
    Sret => self.execute_system(instruction, current_pc, next_pc, raw)
    Unknown(_) => self.execute_system(instruction, current_pc, next_pc, raw)
  }
}

///|
pub fn Runner::run(self : Runner, max_steps : Int) -> StepResult {
  let mut steps = 0
  while steps < max_steps {
    match self.step() {
      Running => steps = steps + 1
      result => return result
    }
  }
  Running
}

///|
pub fn words_to_bytes(words : Array[UInt]) -> Bytes {
  let bytes = []
  let mut index = 0
  while index < words.length() {
    let word = words[index]
    bytes.push(word.to_byte())
    bytes.push((word >> 8).to_byte())
    bytes.push((word >> 16).to_byte())
    bytes.push((word >> 24).to_byte())
    index = index + 1
  }
  Bytes::from_array(bytes)
}

///|
pub fn demo_program_words() -> Array[UInt] {
  [0x00200093U, 0x00508113U, 0x002081b3U, 0x00302023U, 0x00002203U]
}
