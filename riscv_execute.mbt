// Scalar instruction execution, trap routing, CSR side effects, fetch/decode
// dispatch, and Sv39 translation entry points. Code here should preserve
// architectural ordering: timer update, interrupt delivery, fetch, execute.

///|
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
    XLEN_64 =>
      self.write_xlen_reg(
        rd,
        sign_extend_64(value & 0xffffffffU.to_uint64(), 32),
      )
    _ => abort("unsupported xlen for word writeback")
  }
}

///|
fn Runner::step_next_pc(self : Runner, delta : Int) -> UInt64 {
  self.cpu.pc + int_to_uint64_bits(delta)
}

///|
fn Runner::instruction_alignment_bytes(self : Runner) -> UInt64 {
  // RVC lowers IALIGN from 32 bits to 16 bits. Taken branches and jumps use
  // this profile rule; sequential fetch alignment is checked by the fetch path.
  if (self.config.extensions & MISA_EXT_C) != 0U.to_uint64() {
    2U.to_uint64()
  } else {
    4U.to_uint64()
  }
}

///|
fn Runner::instruction_target_aligned(self : Runner, target : UInt64) -> Bool {
  target % self.instruction_alignment_bytes() == 0U.to_uint64()
}

///|
fn Runner::jump_to_instruction_target(
  self : Runner,
  target : UInt64,
  current_pc : UInt64,
) -> StepResult {
  if !self.instruction_target_aligned(target) {
    return self.raise_trap(InstructionAddressMisaligned, current_pc, target)
  }
  self.cpu.pc = target
  Running
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

///|
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
        bool_to_reg(
          xlen_compare_signed(
            self.cpu.read_reg(rs1),
            int_to_uint64_bits(imm),
            xlen,
          ) <
          0,
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    Sltiu(rd, rs1, imm) => {
      self.write_xlen_reg(
        rd,
        bool_to_reg(
          xlen_compare_unsigned(
            self.cpu.read_reg(rs1),
            int_to_uint64_bits(imm),
            xlen,
          ) <
          0,
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
      self.write_word_reg(
        rd,
        low32(self.cpu.read_reg(rs1)).to_uint64() >> shamt,
      )
      self.cpu.pc = next_pc
      Running
    }
    Sraiw(rd, rs1, shamt) => {
      self.write_word_reg(
        rd,
        arithmetic_shift_right_32(self.cpu.read_reg(rs1), shamt),
      )
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
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sub(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2),
          )
          self.cpu.pc = next_pc
          Running
        }
        Addw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2),
          )
          self.cpu.pc = next_pc
          Running
        }
        Subw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sll(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) <<
            xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
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
              xlen_compare_signed(
                self.cpu.read_reg(rs1),
                self.cpu.read_reg(rs2),
                xlen,
              ) <
              0,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sltu(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            bool_to_reg(
              xlen_compare_unsigned(
                self.cpu.read_reg(rs1),
                self.cpu.read_reg(rs2),
                xlen,
              ) <
              0,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Xor(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) ^ self.cpu.read_reg(rs2),
          )
          self.cpu.pc = next_pc
          Running
        }
        Srl(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) >>
            xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
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
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) | self.cpu.read_reg(rs2),
          )
          self.cpu.pc = next_pc
          Running
        }
        And(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) & self.cpu.read_reg(rs2),
          )
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
      self.write_word_reg(
        rd,
        low32(self.cpu.read_reg(rs1)).to_uint64() *
        low32(self.cpu.read_reg(rs2)).to_uint64(),
      )
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
      self.write_word_reg(
        rd,
        div_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)),
      )
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
      self.write_word_reg(
        rd,
        divu_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)),
      )
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
      self.write_word_reg(
        rd,
        rem_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)),
      )
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
      self.write_word_reg(
        rd,
        remu_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)),
      )
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
  current_pc : UInt64,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Beq(rs1, rs2, imm) =>
      if self.cpu.read_reg(rs1) == self.cpu.read_reg(rs2) {
        self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
      } else {
        self.cpu.pc = next_pc
        Running
      }
    Bne(rs1, rs2, imm) =>
      if self.cpu.read_reg(rs1) != self.cpu.read_reg(rs2) {
        self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
      } else {
        self.cpu.pc = next_pc
        Running
      }
    Blt(rs1, rs2, imm) =>
      if xlen_compare_signed(
          self.cpu.read_reg(rs1),
          self.cpu.read_reg(rs2),
          xlen,
        ) <
        0 {
        self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
      } else {
        self.cpu.pc = next_pc
        Running
      }
    Bge(rs1, rs2, imm) =>
      if xlen_compare_signed(
          self.cpu.read_reg(rs1),
          self.cpu.read_reg(rs2),
          xlen,
        ) >=
        0 {
        self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
      } else {
        self.cpu.pc = next_pc
        Running
      }
    Bltu(rs1, rs2, imm) =>
      if xlen_compare_unsigned(
          self.cpu.read_reg(rs1),
          self.cpu.read_reg(rs2),
          xlen,
        ) <
        0 {
        self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
      } else {
        self.cpu.pc = next_pc
        Running
      }
    Bgeu(rs1, rs2, imm) =>
      if xlen_compare_unsigned(
          self.cpu.read_reg(rs1),
          self.cpu.read_reg(rs2),
          xlen,
        ) >=
        0 {
        self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
      } else {
        self.cpu.pc = next_pc
        Running
      }
    _ => abort("unexpected branch dispatch")
  }
}

///|
fn Runner::checked_load_pa(
  self : Runner,
  rs1 : Int,
  imm : Int,
  width : Int,
) -> (UInt64, StepResult?) {
  let addr = self.address_from(rs1, imm)
  self.load_check(addr, width)
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
  let (pa, check) = self.checked_load_pa(rs1, imm, width)
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
    Lb(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 1)
      match check {
        Some(result) => result
        None => {
          self.write_xlen_reg(
            rd,
            xlen_load_sign_extend(self.phy_load_u8(pa), 8, xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lh(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 2)
      match check {
        Some(result) => result
        None => {
          self.write_xlen_reg(
            rd,
            xlen_load_sign_extend(self.phy_load_u16(pa), 16, xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lw(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 4)
      match check {
        Some(result) => result
        None => {
          self.write_word_reg(rd, self.phy_load_u32(pa))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lwu(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 4)
      match check {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.phy_load_u32(pa))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Ld(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 8)
      match check {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.phy_load_u64(pa))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lbu(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 1)
      match check {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.phy_load_u8(pa))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lhu(rd, rs1, imm) => {
      let (pa, check) = self.checked_load_pa(rs1, imm, 2)
      match check {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.phy_load_u16(pa))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    _ => abort("unexpected load dispatch")
  }
}

///|
fn Runner::checked_store_pa(
  self : Runner,
  rs1 : Int,
  imm : Int,
  width : Int,
) -> (UInt64, StepResult?) {
  let addr = self.address_from(rs1, imm)
  self.store_check(addr, width)
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
  let (pa, check) = self.checked_store_pa(rs1, imm, width)
  match check {
    Some(result) => result
    None => {
      store(pa)
      self.invalidate_lr_sc_reservations(pa, width)
      self.cpu.pc = next_pc
      Running
    }
  }
}

///|
const LR_SC_NO_RESERVATION : UInt64 = 0xffffffffffffffff

///|
fn Runner::lr_sc_hart_index(self : Runner) -> Int {
  self.config.hart_id.to_int()
}

///|
fn Runner::set_lr_sc_reservation(
  self : Runner,
  pa : UInt64,
  width : Int,
) -> Unit {
  let hart = self.lr_sc_hart_index()
  self.lr_sc_reserved_pas[hart] = pa
  self.lr_sc_reserved_sizes[hart] = width
}

///|
fn Runner::clear_lr_sc_reservation(self : Runner) -> Unit {
  let hart = self.lr_sc_hart_index()
  self.lr_sc_reserved_pas[hart] = LR_SC_NO_RESERVATION
  self.lr_sc_reserved_sizes[hart] = 0
}

///|
fn physical_ranges_overlap(
  left_pa : UInt64,
  left_width : Int,
  right_pa : UInt64,
  right_width : Int,
) -> Bool {
  let left_end = left_pa + left_width.to_uint64()
  let right_end = right_pa + right_width.to_uint64()
  left_pa < right_end && right_pa < left_end
}

///|
fn Runner::invalidate_lr_sc_reservations(
  self : Runner,
  pa : UInt64,
  width : Int,
) -> Unit {
  for hart in 0..<self.lr_sc_reserved_pas.length() {
    let reserved_pa = self.lr_sc_reserved_pas[hart]
    let reserved_width = self.lr_sc_reserved_sizes[hart]
    if reserved_width != 0 &&
      physical_ranges_overlap(reserved_pa, reserved_width, pa, width) {
      self.lr_sc_reserved_pas[hart] = LR_SC_NO_RESERVATION
      self.lr_sc_reserved_sizes[hart] = 0
    }
  }
}

///|
fn Runner::lr_sc_reservation_matches(
  self : Runner,
  pa : UInt64,
  width : Int,
) -> Bool {
  let hart = self.lr_sc_hart_index()
  self.lr_sc_reserved_pas[hart] == pa &&
  self.lr_sc_reserved_sizes[hart] == width
}

///|
fn Runner::device_store_u8(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  self.bus.store_u8(pa, value)
  self.invalidate_lr_sc_reservations(pa, 1)
}

///|
fn Runner::device_store_u16(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  self.bus.store_u16(pa, value)
  self.invalidate_lr_sc_reservations(pa, 2)
}

///|
fn Runner::device_store_u32(self : Runner, pa : UInt64, value : UInt64) -> Unit {
  self.bus.store_u32(pa, value)
  self.invalidate_lr_sc_reservations(pa, 4)
}

///|
fn Runner::device_write_bytes_from(
  self : Runner,
  pa : UInt64,
  bytes : Bytes,
  source_offset : Int,
  len : Int,
) -> Int {
  let copied = self.bus.write_bytes_from(pa, bytes, source_offset, len)
  if copied > 0 {
    self.invalidate_lr_sc_reservations(pa, copied)
  }
  copied
}

///|
fn Runner::execute_store(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Sb(rs1, rs2, imm) => {
      let (pa, check) = self.checked_store_pa(rs1, imm, 1)
      match check {
        Some(result) => result
        None => {
          self.phy_store_u8(pa, self.cpu.read_reg(rs2))
          self.invalidate_lr_sc_reservations(pa, 1)
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Sh(rs1, rs2, imm) => {
      let (pa, check) = self.checked_store_pa(rs1, imm, 2)
      match check {
        Some(result) => result
        None => {
          self.phy_store_u16(pa, self.cpu.read_reg(rs2))
          self.invalidate_lr_sc_reservations(pa, 2)
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Sw(rs1, rs2, imm) => {
      let (pa, check) = self.checked_store_pa(rs1, imm, 4)
      match check {
        Some(result) => result
        None => {
          self.phy_store_u32(pa, self.cpu.read_reg(rs2))
          self.invalidate_lr_sc_reservations(pa, 4)
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Sd(rs1, rs2, imm) => {
      let (pa, check) = self.checked_store_pa(rs1, imm, 8)
      match check {
        Some(result) => result
        None => {
          self.phy_store_u64(pa, self.cpu.read_reg(rs2))
          self.invalidate_lr_sc_reservations(pa, 8)
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    _ => abort("unexpected store dispatch")
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
      if xlen_compare_signed(old_val, src, xlen) <= 0 {
        old_val
      } else {
        src
      }
    0x14U => // AMOMAX (signed)
      if xlen_compare_signed(old_val, src, xlen) >= 0 {
        old_val
      } else {
        src
      }
    0x18U => // AMOMINU (unsigned)
      if xlen_compare_unsigned(old_val, src, xlen) <= 0 {
        old_val
      } else {
        src
      }
    0x1cU => // AMOMAXU (unsigned)
      if xlen_compare_unsigned(old_val, src, xlen) >= 0 {
        old_val
      } else {
        src
      }
    _ => old_val // should not happen; caller validates
  }
}

///|
fn amo_w_op(funct5 : UInt, old_raw : UInt64, src : UInt64) -> UInt64 {
  let src_word = src & 0xffffffffU.to_uint64()
  match funct5 {
    0x01U => src_word // AMOSWAP.W
    0x00U => old_raw + src_word // AMOADD.W
    0x04U => old_raw ^ src_word // AMOXOR.W
    0x0cU => old_raw & src_word // AMOAND.W
    0x08U => old_raw | src_word // AMOOR.W
    0x10U => // AMOMIN.W (signed 32-bit)
      if compare_signed_32(old_raw, src_word) <= 0 {
        old_raw
      } else {
        src_word
      }
    0x14U => // AMOMAX.W (signed 32-bit)
      if compare_signed_32(old_raw, src_word) >= 0 {
        old_raw
      } else {
        src_word
      }
    0x18U => // AMOMINU.W
      if compare_unsigned_32(old_raw, src_word) <= 0 {
        old_raw
      } else {
        src_word
      }
    0x1cU => // AMOMAXU.W
      if compare_unsigned_32(old_raw, src_word) >= 0 {
        old_raw
      } else {
        src_word
      }
    _ => old_raw // should not happen; caller validates
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
  // AMO and LR/SC operations share the same physical-address reservation
  // model as normal stores. This does not yet give `aq`/`rl` a full memory
  // ordering model, but it does enforce the A-extension rule that another
  // hart's store to the reservation set can make a later SC fail.
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
        self.set_lr_sc_reservation(pa, 4)
        self.write_xlen_reg(rd, sign_extended)
        self.cpu.pc = next_pc
        return Running
      }
      // SC.W succeeds only against a live matching reservation.
      if funct5_val == 0x03U {
        let (pa, check) = self.store_check(addr, 4)
        match check {
          Some(result) => return result
          None => ()
        }
        if self.lr_sc_reservation_matches(pa, 4) {
          self.phy_store_u32(pa, self.cpu.read_reg(rs2))
          self.invalidate_lr_sc_reservations(pa, 4)
          self.write_xlen_reg(rd, 0U.to_uint64()) // 0 = success
        } else {
          self.write_xlen_reg(rd, 1U.to_uint64())
        }
        self.clear_lr_sc_reservation()
        self.cpu.pc = next_pc
        return Running
      }
      // Other AMO.W: load-op-store
      let (pa, check) = self.store_check(addr, 4)
      match check {
        Some(result) => return result
        None => ()
      }
      let old_raw = self.phy_load_u32(pa)
      let old_val = xlen_sign_extend(old_raw, 32, self.xlen_bits())
      let src = self.cpu.read_reg(rs2)
      let new_val = amo_w_op(funct5_val, old_raw, src)
      self.phy_store_u32(pa, new_val)
      self.invalidate_lr_sc_reservations(pa, 4)
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
        self.set_lr_sc_reservation(pa, 8)
        self.write_xlen_reg(rd, loaded)
        self.cpu.pc = next_pc
        return Running
      }
      // SC.D succeeds only against a live matching reservation.
      if funct5_val == 0x03U {
        let (pa, check) = self.store_check(addr, 8)
        match check {
          Some(result) => return result
          None => ()
        }
        if self.lr_sc_reservation_matches(pa, 8) {
          self.phy_store_u64(pa, self.cpu.read_reg(rs2))
          self.invalidate_lr_sc_reservations(pa, 8)
          self.write_xlen_reg(rd, 0U.to_uint64())
        } else {
          self.write_xlen_reg(rd, 1U.to_uint64())
        }
        self.clear_lr_sc_reservation()
        self.cpu.pc = next_pc
        return Running
      }
      // Other AMO.D: load-op-store
      let (pa, check) = self.store_check(addr, 8)
      match check {
        Some(result) => return result
        None => ()
      }
      let old_val = self.phy_load_u64(pa)
      let src = self.cpu.read_reg(rs2)
      let new_val = amo_op(funct5_val, old_val, src, self.xlen_bits())
      self.phy_store_u64(pa, new_val)
      self.invalidate_lr_sc_reservations(pa, 8)
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
  current_pc : UInt64,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Jal(rd, imm) => {
      self.write_xlen_reg(rd, next_pc)
      self.jump_to_instruction_target(self.step_next_pc(imm), current_pc)
    }
    Jalr(rd, rs1, imm) => {
      let target = (self.cpu.read_reg(rs1) + int_to_uint64_bits(imm)) &
        bit_not(1U.to_uint64())
      self.write_xlen_reg(rd, next_pc)
      self.jump_to_instruction_target(target, current_pc)
    }
    _ => abort("unexpected jump dispatch")
  }
}

///|
fn Runner::read_csr_visible(self : Runner, csr : Int) -> UInt64 {
  // Some architectural CSRs are aliases or filtered views of a backing CSR.
  // Keep that visibility rule centralized so instruction handlers and probe
  // reporting observe the same value Linux would read.
  match csr {
    CSR_CYCLE => self.mcycle
    CSR_MCYCLE => self.mcycle
    CSR_TIME => self.clint_mtime()
    CSR_INSTRET => self.minstret
    CSR_MINSTRET => self.minstret
    CSR_CYCLEH => self.mcycle >> 32
    CSR_MCYCLEH => self.mcycle >> 32
    CSR_TIMEH => self.clint_mtime() >> 32
    CSR_INSTRETH => self.minstret >> 32
    CSR_MINSTRETH => self.minstret >> 32
    CSR_MISA => misa_value(self.config.xlen, self.config.extensions)
    CSR_FFLAGS => self.read_fcsr() & FCSR_FFLAGS_MASK
    CSR_FRM => (self.read_fcsr() & FCSR_FRM_MASK) >> FCSR_FRM_SHIFT
    CSR_FCSR => self.read_fcsr()
    CSR_VXSAT => self.read_vcsr() & VCSR_VXSAT_MASK
    CSR_VXRM => (self.read_vcsr() & VCSR_VXRM_MASK) >> VCSR_VXRM_SHIFT
    CSR_VCSR => self.read_vcsr()
    CSR_VLENB => VLEN_BYTES.to_uint64()
    CSR_MSTATUS =>
      legalize_mstatus_csr(self.cpu.read_csr(CSR_MSTATUS), self.config.xlen)
    CSR_SSTATUS =>
      legalize_mstatus_csr(self.cpu.read_csr(CSR_MSTATUS), self.config.xlen) &
      SSTATUS_VISIBLE_MASK
    CSR_MEDELEG => legalize_medeleg_csr(self.cpu.read_csr(CSR_MEDELEG))
    CSR_MIDELEG => legalize_mideleg_csr(self.cpu.read_csr(CSR_MIDELEG))
    CSR_MCOUNTEREN => legalize_counteren_csr(self.cpu.read_csr(CSR_MCOUNTEREN))
    CSR_SCOUNTEREN => legalize_counteren_csr(self.cpu.read_csr(CSR_SCOUNTEREN))
    CSR_MCOUNTINHIBIT =>
      legalize_mcountinhibit_csr(self.cpu.read_csr(CSR_MCOUNTINHIBIT))
    CSR_MENVCFG | CSR_SENVCFG => legalize_envcfg_csr(self.cpu.read_csr(csr))
    CSR_PMPCFG0 | CSR_PMPADDR0 => legalize_pmp_csr(self.cpu.read_csr(csr))
    CSR_MIP => self.read_mip_visible()
    CSR_MIE => legalize_mie_csr(self.cpu.read_csr(CSR_MIE))
    CSR_SIP => self.read_mip_visible() & self.delegated_s_interrupt_mask()
    CSR_SIE => self.cpu.read_csr(CSR_MIE) & self.delegated_s_interrupt_mask()
    _ => self.cpu.read_csr(csr)
  }
}

///|
fn Runner::read_mip_visible(self : Runner) -> UInt64 {
  let stored = legalize_mip_csr(self.cpu.read_csr(CSR_MIP))
  // The privileged spec defines mip.SEIP as a visible OR of the
  // software-writable bit B and the external interrupt-controller signal E.
  // The stored CSR holds only B; platform PLIC state supplies E at read time.
  if self.supervisor_external_interrupt_pending() {
    stored | mip_seip_bit
  } else {
    stored
  }
}

///|
fn Runner::csr_rmw_write_base(
  self : Runner,
  csr : Int,
  visible_old : UInt64,
) -> UInt64 {
  // CSRRS/CSRRC normally write from the value read into rd. mip.SEIP is the
  // architectural exception: reads include the external PLIC signal E, but the
  // read-modify-write sequence updates only the software bit B. Use the stored
  // CSR value as the write base for mip so E is never copied into B.
  if csr == CSR_MIP {
    legalize_mip_csr(self.cpu.read_csr(CSR_MIP))
  } else {
    visible_old
  }
}

///|
fn Runner::delegated_s_interrupt_mask(self : Runner) -> UInt64 {
  // sip/sie are restricted views of mip/mie. Supervisor-visible interrupt bits
  // appear only after M-mode delegates the corresponding source through mideleg.
  legalize_mideleg_csr(self.cpu.read_csr(CSR_MIDELEG)) & SIP_VISIBLE_MASK
}

///|
fn Runner::writable_sip_mask(self : Runner) -> UInt64 {
  // Through the supervisor view, only SSIP is software-writable. Timer and
  // external interrupt pending bits are supplied by the execution environment.
  self.delegated_s_interrupt_mask() & SIP_WRITABLE_MASK
}

///|
fn legalize_trap_vector_csr(value : UInt64) -> UInt64 {
  // mtvec/stvec are WARL. The modeled platform supports the standard Direct
  // and Vectored modes and requires the architectural 4-byte BASE alignment.
  // Reserved MODE values are normalized to Direct while preserving BASE.
  let base = value & bit_not(0x3U.to_uint64())
  let mode = value & 0x3U.to_uint64()
  if mode == 1U.to_uint64() {
    base | mode
  } else {
    base
  }
}

///|
fn legalize_epc_csr(value : UInt64) -> UInt64 {
  // mepc[0] and sepc[0] are architecturally hardwired to zero. Bit 1 remains
  // representable for this RV64GC baseline because compressed instructions make
  // IALIGN=16.
  value & bit_not(1U.to_uint64())
}

///|
fn legalize_medeleg_csr(value : UInt64) -> UInt64 {
  // This RV64GC profile delegates only exception causes the emulator can raise
  // from U/S-mode. Machine-only causes such as M-mode ecall remain read-only
  // zero as required by the privileged architecture.
  value & MEDELEG_WRITABLE_MASK
}

///|
fn legalize_mideleg_csr(value : UInt64) -> UInt64 {
  // S-level software, timer, and external interrupts are the only delegated
  // interrupt sources modeled for the current QEMU-virt-like single-hart path.
  value & MIDELEG_WRITABLE_MASK
}

///|
fn legalize_counteren_csr(value : UInt64) -> UInt64 {
  // Only the base counters exist in this RV64GC profile. HPM counter enables
  // are WARL read-only zero because the corresponding hpmcounter CSRs are not
  // implemented.
  value & COUNTEREN_WRITABLE_MASK
}

///|
fn legalize_mcountinhibit_csr(value : UInt64) -> UInt64 {
  // The profile exposes mcycle and minstret, but not HPM counters. mtime is a
  // platform timer and is explicitly outside the mcountinhibit mechanism, so
  // only CY and IR are writable here.
  value & MCOUNTINHIBIT_WRITABLE_MASK
}

///|
fn legalize_envcfg_csr(_value : UInt64) -> UInt64 {
  // menvcfg/senvcfg mostly enable optional execution-environment features:
  // FIOM, Svpbmt, Svadu, Sstc, cache-block ops, pointer masking, landing pads,
  // shadow stacks, and double-trap controls. None are implemented in the
  // current RV64GC baseline, so their fields are read-only zero.
  0U.to_uint64()
}

///|
fn legalize_pmp_csr(_value : UInt64) -> UInt64 {
  // PMP is optional, and this emulator currently has no PMP enforcement in
  // instruction fetch, load/store, page-table walks, or M-mode accesses. Expose
  // zero implemented PMP entries until those access checks exist; otherwise
  // firmware could configure protection rules that the emulator silently
  // ignores.
  0U.to_uint64()
}

///|
fn legalize_mie_csr(value : UInt64) -> UInt64 {
  // The modeled platform can raise the standard machine and supervisor
  // software/timer/external interrupts. Other interrupt-enable bits are WARL
  // read-only zero.
  value & MACHINE_INTERRUPT_MASK
}

///|
fn legalize_mip_csr(value : UInt64) -> UInt64 {
  // Pending bits reflect implemented interrupt sources only. Machine-level
  // pending bits are supplied by CLINT/PLIC state, while S-level pending bits
  // can also be written by M-mode software through mip.
  value & MACHINE_INTERRUPT_MASK
}

///|
fn legalize_mstatus_csr(value : UInt64, xlen : Xlen) -> UInt64 {
  // The interpreter models a fixed privileged ISA surface, not arbitrary
  // future mstatus bits. Drop unsupported user-interrupt, VS, XS, and WPRI
  // storage before applying the fields that have profile-specific WARL rules.
  let implemented = value & MSTATUS_IMPLEMENTED_MASK
  // SD is a read-only summary bit. For the current RV64GC baseline the modeled
  // dirty extension status is FS=Dirty; future VS/XS modeling should join this
  // summary rather than making SD directly writable.
  let without_sd = implemented & bit_not(MSTATUS_SD_BIT)
  let fs_dirty = (without_sd & MSTATUS_FS_MASK) == MSTATUS_FS_DIRTY
  let summarized = if fs_dirty {
    without_sd | MSTATUS_SD_BIT
  } else {
    without_sd
  }
  // The current memory system is little-endian only. Model MBE/SBE/UBE as
  // read-only zero WARL fields until an endian-switching load/store path exists.
  let little_endian_status = summarized & bit_not(MSTATUS_ENDIAN_MASK)
  // This emulator models fixed-width lower privilege modes. On RV64, expose
  // SXLEN=UXLEN=64 as read-only WARL values; on RV32 these fields do not exist.
  let with_xlen = match xlen {
    Xlen64 =>
      (little_endian_status & bit_not(MSTATUS_SXL_MASK | MSTATUS_UXL_MASK)) |
      MSTATUS_SXL_64 |
      MSTATUS_UXL_64
    Xlen32 => little_endian_status
  }
  // MPP is WARL and may hold only implemented privilege modes. This single-hart
  // profile implements U, S, and M, so the reserved encoding 2 normalizes to U.
  let mpp = (with_xlen & MSTATUS_MPP_MASK.to_uint64()) >> MSTATUS_MPP_SHIFT
  if mpp == 2U.to_uint64() {
    set_mstatus_mpp(with_xlen, User)
  } else {
    with_xlen
  }
}

///|
fn Runner::write_csr_visible(self : Runner, csr : Int, value : UInt64) -> Unit {
  // Writes mirror read_csr_visible: aliases update their backing CSR and WARL
  // fields normalize at the write boundary. Avoid duplicating these rules in
  // individual CSR instruction cases.
  match csr {
    CSR_MTVEC | CSR_STVEC =>
      self.cpu.write_csr(csr, legalize_trap_vector_csr(value))
    CSR_MEPC | CSR_SEPC => self.cpu.write_csr(csr, legalize_epc_csr(value))
    CSR_MEDELEG => self.cpu.write_csr(csr, legalize_medeleg_csr(value))
    CSR_MIDELEG => self.cpu.write_csr(csr, legalize_mideleg_csr(value))
    CSR_MCOUNTEREN | CSR_SCOUNTEREN =>
      self.cpu.write_csr(csr, legalize_counteren_csr(value))
    CSR_MCOUNTINHIBIT =>
      self.cpu.write_csr(csr, legalize_mcountinhibit_csr(value))
    CSR_MISA =>
      // `misa` is WARL rather than address-encoded read-only. This emulator
      // exposes a fixed ISA profile for a Runner, so writes retire but read
      // back the configured extension set.
      self.cpu.write_csr(
        csr,
        misa_value(self.config.xlen, self.config.extensions),
      )
    CSR_MCYCLE => self.mcycle = value
    CSR_MINSTRET => self.minstret = value
    CSR_MCYCLEH =>
      self.mcycle = (self.mcycle & 0xffffffffU.to_uint64()) |
        ((value & 0xffffffffU.to_uint64()) << 32)
    CSR_MINSTRETH =>
      self.minstret = (self.minstret & 0xffffffffU.to_uint64()) |
        ((value & 0xffffffffU.to_uint64()) << 32)
    CSR_MENVCFG | CSR_SENVCFG =>
      self.cpu.write_csr(csr, legalize_envcfg_csr(value))
    CSR_PMPCFG0 | CSR_PMPADDR0 =>
      self.cpu.write_csr(csr, legalize_pmp_csr(value))
    CSR_MIE => self.cpu.write_csr(csr, legalize_mie_csr(value))
    CSR_MIP => {
      let mip = self.cpu.read_csr(CSR_MIP)
      self.cpu.write_csr(
        csr,
        (mip & bit_not(MIP_WRITABLE_MASK)) | (value & MIP_WRITABLE_MASK),
      )
    }
    CSR_MSTATUS =>
      self.cpu.write_csr(csr, legalize_mstatus_csr(value, self.config.xlen))
    CSR_FFLAGS => {
      let fcsr = self.read_fcsr()
      self.write_fcsr(
        (fcsr & bit_not(FCSR_FFLAGS_MASK)) | (value & FCSR_FFLAGS_MASK),
      )
    }
    CSR_FRM => {
      let fcsr = self.read_fcsr()
      let frm_bits = (value & 0x7U.to_uint64()) << FCSR_FRM_SHIFT
      self.write_fcsr((fcsr & bit_not(FCSR_FRM_MASK)) | frm_bits)
    }
    CSR_FCSR => self.write_fcsr(value)
    CSR_VXSAT => {
      let vcsr = self.read_vcsr()
      self.write_vcsr(
        (vcsr & bit_not(VCSR_VXSAT_MASK)) | (value & VCSR_VXSAT_MASK),
      )
    }
    CSR_VXRM => {
      let vcsr = self.read_vcsr()
      let vxrm_bits = (value & 0x3U.to_uint64()) << VCSR_VXRM_SHIFT
      self.write_vcsr((vcsr & bit_not(VCSR_VXRM_MASK)) | vxrm_bits)
    }
    CSR_VCSR => self.write_vcsr(value)
    CSR_SSTATUS => {
      let mstatus = self.cpu.read_csr(CSR_MSTATUS)
      let next_mstatus = (mstatus & bit_not(SSTATUS_VISIBLE_MASK)) |
        (value & SSTATUS_VISIBLE_MASK)
      self.cpu.write_csr(
        CSR_MSTATUS,
        legalize_mstatus_csr(next_mstatus, self.config.xlen),
      )
    }
    CSR_SIP => {
      let mip = self.cpu.read_csr(CSR_MIP)
      let writable = self.writable_sip_mask()
      self.cpu.write_csr(
        CSR_MIP,
        (mip & bit_not(writable)) | (value & writable),
      )
    }
    CSR_SIE => {
      let mie = self.cpu.read_csr(CSR_MIE)
      let visible = self.delegated_s_interrupt_mask()
      self.cpu.write_csr(CSR_MIE, (mie & bit_not(visible)) | (value & visible))
    }
    CSR_SATP => {
      // WARL: satp.MODE field. Only mode=0 (Bare) and mode=8 (Sv39) are
      // supported. The privileged spec says writes with unsupported MODE have
      // no effect at all, so preserve the previous address-space selector.
      let mode = (value >> 60) & 0xFU.to_uint64()
      if mode == 0U.to_uint64() || mode == 8U.to_uint64() {
        self.cpu.write_csr(CSR_SATP, value)
        self.flush_translate_cache()
      } else {
        ()
      }
    }
    _ => self.cpu.write_csr(csr, value)
  }
}

///|
fn counter_csr_enable_bit(csr : Int) -> UInt64? {
  match csr {
    CSR_CYCLE | CSR_CYCLEH => Some(1U.to_uint64())
    CSR_TIME | CSR_TIMEH => Some(1U.to_uint64() << 1)
    CSR_INSTRET | CSR_INSTRETH => Some(1U.to_uint64() << 2)
    _ => None
  }
}

///|
fn machine_counter_high_csr(csr : Int) -> Bool {
  match csr {
    CSR_MCYCLEH | CSR_MINSTRETH => true
    _ => false
  }
}

///|
fn Runner::counter_csr_accessible(self : Runner, csr : Int) -> Bool {
  let bit = match counter_csr_enable_bit(csr) {
    Some(bit) => bit
    None => return true
  }
  match self.cpu.privilege {
    Machine => true
    Supervisor =>
      (self.read_csr_visible(CSR_MCOUNTEREN) & bit) != 0U.to_uint64()
    User =>
      (self.read_csr_visible(CSR_MCOUNTEREN) & bit) != 0U.to_uint64() &&
      (self.read_csr_visible(CSR_SCOUNTEREN) & bit) != 0U.to_uint64()
  }
}

///|
fn privilege_rank(mode : PrivilegeMode) -> Int {
  match mode {
    User => 0
    Supervisor => 1
    Machine => 3
  }
}

///|
fn csr_min_privilege_rank(csr : Int) -> Int {
  (csr >> 8) & 0x3
}

///|
fn Runner::csr_privilege_accessible(self : Runner, csr : Int) -> Bool {
  privilege_rank(self.cpu.privilege) >= csr_min_privilege_rank(csr)
}

///|
fn Runner::csr_tvm_accessible(self : Runner, csr : Int) -> Bool {
  if csr != CSR_SATP {
    return true
  }
  match self.cpu.privilege {
    Supervisor =>
      (self.cpu.read_csr(CSR_MSTATUS) & MSTATUS_TVM_BIT) == 0U.to_uint64()
    _ => true
  }
}

///|
fn Runner::csr_extension_state_accessible(self : Runner, csr : Int) -> Bool {
  // Floating-point CSRs are part of the FS-governed state described by the
  // privileged spec. Their address privilege may be unprivileged, but FS=Off
  // still makes attempts to read or write them illegal.
  if is_modeled_fp_csr(csr) {
    self.fp_context_enabled()
  } else {
    true
  }
}

///|
fn Runner::read_csr_checked(self : Runner, csr : Int) -> UInt64? {
  if self.xlen_bits() == XLEN_64 {
    match csr {
      CSR_CYCLEH | CSR_TIMEH | CSR_INSTRETH | CSR_MCYCLEH | CSR_MINSTRETH =>
        return None
      _ => ()
    }
  }
  if !self.csr_privilege_accessible(csr) {
    return None
  }
  if !self.csr_tvm_accessible(csr) {
    return None
  }
  if !self.counter_csr_accessible(csr) {
    return None
  }
  if !self.csr_extension_state_accessible(csr) {
    return None
  }
  if is_supported_csr(csr, self.config.extensions) {
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
  should_read : Bool,
  should_write : Bool,
  next_pc : UInt64,
  current_pc : UInt64,
  raw : UInt,
) -> StepResult {
  // Zicsr makes read and write suppression part of the architectural contract:
  // CSRRW[I] with rd=x0 must not read, and CSRRS/CSRRC[I] with a zero mask must
  // not write. Keep those checks explicit so trap behavior follows the
  // instruction form rather than a generic always-read/read-modify-write path.
  // Suppressing the read does not suppress write-side privilege or legality.
  // Conversely, CSRRS/CSRRC with x0 or uimm=0 are pure reads: even read-only
  // CSRs are legal there because no architectural write is attempted.
  let old_value = if should_read {
    match self.read_csr_checked(csr) {
      Some(value) => value
      None =>
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
  } else {
    0U.to_uint64()
  }
  if should_write {
    if self.xlen_bits() == XLEN_64 && machine_counter_high_csr(csr) {
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
    if !self.csr_privilege_accessible(csr) ||
      !self.csr_tvm_accessible(csr) ||
      !self.csr_extension_state_accessible(csr) ||
      !is_supported_rw_csr(csr, self.config.extensions) {
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
  // SYSTEM groups CSR ops, privilege returns, fences, waits, and unknown
  // encodings. Decode keeps them together so privilege/CSR checks stay in one
  // execution path instead of leaking into unrelated instruction handlers.
  match instruction {
    Csrrw(rd, csr, rs1) =>
      self.execute_csr_read_write_checked(
        rd,
        csr,
        self.cpu.read_reg(rs1),
        rd != 0,
        true,
        next_pc,
        current_pc,
        raw,
      )
    Csrrs(rd, csr, rs1) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let write_base = self.csr_rmw_write_base(csr, old_value)
      self.execute_csr_read_write_checked(
        rd,
        csr,
        write_base | self.cpu.read_reg(rs1),
        true,
        rs1 != 0,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrc(rd, csr, rs1) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let write_base = self.csr_rmw_write_base(csr, old_value)
      self.execute_csr_read_write_checked(
        rd,
        csr,
        write_base & bit_not(self.cpu.read_reg(rs1)),
        true,
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
        rd != 0,
        true,
        next_pc,
        current_pc,
        raw,
      )
    Csrrsi(rd, csr, uimm) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let write_base = self.csr_rmw_write_base(csr, old_value)
      self.execute_csr_read_write_checked(
        rd,
        csr,
        write_base | uimm.to_uint64(),
        true,
        uimm != 0U,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrci(rd, csr, uimm) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      let write_base = self.csr_rmw_write_base(csr, old_value)
      self.execute_csr_read_write_checked(
        rd,
        csr,
        write_base & bit_not(uimm.to_uint64()),
        true,
        uimm != 0U,
        next_pc,
        current_pc,
        raw,
      )
    }
    SfenceVma(_, _) => {
      match self.cpu.privilege {
        Machine => ()
        Supervisor =>
          if (self.cpu.read_csr(CSR_MSTATUS) & MSTATUS_TVM_BIT) !=
            0U.to_uint64() {
            return self.raise_trap(
              IllegalInstruction,
              current_pc,
              raw.to_uint64(),
            )
          }
        User =>
          return self.raise_trap(
            IllegalInstruction,
            current_pc,
            raw.to_uint64(),
          )
      }
      // SFENCE.VMA is a privileged instruction with a visible emulator-side
      // effect: stale Sv39 translations must not survive once the instruction
      // has passed its privilege and TVM checks.
      self.flush_translate_cache()
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
    Ebreak => self.raise_trap(Breakpoint, current_pc, 0U.to_uint64())
    Mret => self.execute_mret(current_pc, raw)
    Sret => self.execute_sret(current_pc, raw)
    Unknown(_) =>
      self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    _ => abort("unexpected system dispatch")
  }
}

///|
fn Runner::execute_mret(
  self : Runner,
  current_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match self.cpu.privilege {
    Machine => ()
    _ => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  // Return instructions restore privilege and interrupt-enable state from
  // mstatus before jumping to the saved EPC. The helper functions encode the
  // bit shuffling so this path stays readable.
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  self.cpu.write_csr(CSR_MSTATUS, mstatus_after_mret(mstatus))
  self.cpu.privilege = mstatus_mpp(mstatus)
  self.cpu.pc = legalize_epc_csr(self.cpu.read_csr(CSR_MEPC))
  Running
}

///|
fn Runner::execute_sret(
  self : Runner,
  current_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let sret_from_supervisor = match self.cpu.privilege {
    Machine => false
    Supervisor => true
    User =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  // SRET is the same shape as MRET but uses SPP/SPIE and sepc. Linux relies on
  // this during every user/kernel boundary after userspace is alive.
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  if sret_from_supervisor && (mstatus & MSTATUS_TSR_BIT) != 0U.to_uint64() {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  self.cpu.write_csr(CSR_MSTATUS, mstatus_after_sret(mstatus))
  self.cpu.privilege = mstatus_spp(mstatus)
  self.cpu.pc = legalize_epc_csr(self.cpu.read_csr(CSR_SEPC))
  Running
}

///|
fn Runner::wfi_resume_interrupt_pending(self : Runner) -> Bool {
  (self.read_csr_visible(CSR_MIP) & self.read_csr_visible(CSR_MIE)) !=
  0U.to_uint64()
}

///|
fn Runner::fast_forward_wfi_timer(self : Runner) -> Unit {
  if self.config.clint_base == 0U.to_uint64() ||
    self.wfi_resume_interrupt_pending() {
    return
  }
  let hart_id = self.config.hart_id.to_int()
  let target = self.all_mtimecmp[hart_id]
  let unset = bit_not(0U.to_uint64())
  if target != unset && target > self.mtime[0] {
    // Stop one tick before the compare point. The next step's normal timer
    // update raises MTIP and lets the existing interrupt path choose M/S-mode.
    self.mtime[0] = target - 1U.to_uint64()
  }
}

///|
fn Runner::execute_wfi(
  self : Runner,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match self.cpu.privilege {
    Machine => ()
    Supervisor =>
      if (self.cpu.read_csr(CSR_MSTATUS) & MSTATUS_TW_BIT) != 0U.to_uint64() {
        return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
    User =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  // Legal WFI remains a scheduling hint for this interpreter. If a CLINT timer
  // compare is armed, fast-forward close to it so the next normal step can let
  // the existing interrupt path choose the architectural target mode.
  self.fast_forward_wfi_timer()
  self.cpu.pc = next_pc
  Running
}

///|
// Interrupt priority order (high to low): MEI, MSI, MTI, SEI, SSI, STI
fn interrupt_cause_from_mip_bit(bit : Int) -> TrapCause {
  match bit {
    11 => MachineExternalInterrupt
    3 => MachineSoftwareInterrupt
    7 => MachineTimerInterrupt
    9 => SupervisorExternalInterrupt
    1 => SupervisorSoftwareInterrupt
    5 => SupervisorTimerInterrupt
    _ => MachineTimerInterrupt // fallback
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
  // Interrupt delivery is checked once per step after timer/device state is
  // updated. Delegation chooses the target privilege; priority selection is
  // intentionally small and explicit because Linux boot is sensitive to timer
  // and external interrupt ordering.
  let mip = self.read_csr_visible(CSR_MIP)
  let mie = self.read_csr_visible(CSR_MIE)
  let pending = mip & mie
  if pending == 0U.to_uint64() {
    return None
  }
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let mideleg = self.read_csr_visible(CSR_MIDELEG)
  // Machine-level interrupts: bits NOT in mideleg
  let m_pending = pending & bit_not(mideleg)
  let m_enabled = match self.cpu.privilege {
    Machine => mstatus_mie(mstatus)
    _ => true // M-mode interrupts always preempt lower-privilege modes
  }
  if m_pending != 0U.to_uint64() && m_enabled {
    match highest_interrupt_cause(m_pending) {
      Some(cause) =>
        return Some(self.raise_trap(cause, self.cpu.pc, 0U.to_uint64()))
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
      Some(cause) =>
        return Some(self.raise_trap(cause, self.cpu.pc, 0U.to_uint64()))
      None => ()
    }
  }
  None
}

///|
fn decode_cache_index(fetch_pa : UInt64) -> Int {
  ((fetch_pa >> 1) & (decode_cache_sets - 1).reinterpret_as_uint().to_uint64()).to_int()
}

///|
fn Runner::flush_decode_cache(self : Runner) -> Unit {
  for index in 0..<decode_cache_sets {
    self.decode_cache_tags[index] = decode_cache_invalid_tag
  }
  self.decode_cache_flushes = self.decode_cache_flushes + 1U.to_uint64()
}

///|
fn Runner::decode_cached(
  self : Runner,
  fetch_pa : UInt64,
  raw : UInt,
  length : Int,
) -> Instruction {
  let index = decode_cache_index(fetch_pa)
  let xlen = self.xlen_bits()
  if self.decode_cache_tags[index] == fetch_pa &&
    self.decode_cache_raws[index] == raw &&
    self.decode_cache_lengths[index] == length &&
    self.decode_cache_xlens[index] == xlen {
    self.decode_cache_hits = self.decode_cache_hits + 1U.to_uint64()
    return self.decode_cache_instructions[index]
  }
  self.decode_cache_misses = self.decode_cache_misses + 1U.to_uint64()
  let instruction = if length == 2 {
    decode_compressed(raw, xlen)
  } else {
    decode(raw)
  }
  self.decode_cache_tags[index] = fetch_pa
  self.decode_cache_raws[index] = raw
  self.decode_cache_lengths[index] = length
  self.decode_cache_xlens[index] = xlen
  self.decode_cache_instructions[index] = instruction
  self.decode_cache_fills = self.decode_cache_fills + 1U.to_uint64()
  instruction
}

///|
fn Runner::increment_cycle_counter(self : Runner) -> Unit {
  // mcycle is an architectural counter, not the CLINT timer. It advances for
  // each interpreter step unless machine software has inhibited CY.
  if (self.read_csr_visible(CSR_MCOUNTINHIBIT) & MCOUNTINHIBIT_CY_BIT) ==
    0U.to_uint64() {
    self.mcycle = self.mcycle + 1U.to_uint64()
  }
}

///|
fn Runner::increment_instret_counter(self : Runner, inhibited : Bool) -> Unit {
  // minstret counts instructions that retire. Synchronous traps return before
  // this helper is called, while xRET/WFI and ordinary successful instructions
  // do retire and therefore use this path. The inhibit bit is sampled before
  // execution so writes to mcountinhibit take effect after the writing
  // instruction has otherwise completed.
  if !inhibited {
    self.minstret = self.minstret + 1U.to_uint64()
  }
}

///|
pub fn Runner::step(self : Runner) -> StepResult {
  self.increment_cycle_counter()
  // Advance CLINT mtime and update MIP.MTIP.
  self.update_timer()
  // Deliver pending interrupts before executing the next instruction. This
  // keeps timer/external interrupts observable during long Linux loops.
  match self.take_pending_interrupt() {
    Some(result) => return result
    None => ()
  }
  let current_pc = self.cpu.pc
  let fetched = match self.fetch_instruction(current_pc) {
    (Some(instruction), None) => instruction
    (None, Some(result)) => return result
    _ => abort("unexpected fetch result")
  }
  let next_pc = current_pc + fetched.length.reinterpret_as_uint().to_uint64()
  let raw = fetched.raw
  let instruction = self.decode_cached(fetched.fetch_pa, raw, fetched.length)
  // Extension and XLEN legality is checked after decode so trap values can
  // still report the original raw instruction word.
  if !instruction_supported_for_current_config(
      instruction,
      self.xlen_bits(),
      self.config.extensions,
      fetched.length,
    ) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let instret_inhibited_before_execute = (
      self.read_csr_visible(CSR_MCOUNTINHIBIT) & MCOUNTINHIBIT_IR_BIT
    ) !=
    0U.to_uint64()
  let result = match instruction {
    // The central dispatcher should stay boring: group by architectural family
    // and delegate complicated behavior to focused helpers.
    Fence => {
      self.cpu.pc = next_pc
      Running
    }
    FenceI => {
      self.flush_decode_cache()
      self.cpu.pc = next_pc
      Running
    }
    Lui(rd, imm) => {
      self.write_xlen_reg(
        rd,
        xlen_sign_extend(imm.to_uint64(), 32, self.xlen_bits()),
      )
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
    Beq(_, _, _) => self.execute_branch(instruction, current_pc, next_pc)
    Bne(_, _, _) => self.execute_branch(instruction, current_pc, next_pc)
    Blt(_, _, _) => self.execute_branch(instruction, current_pc, next_pc)
    Bge(_, _, _) => self.execute_branch(instruction, current_pc, next_pc)
    Bltu(_, _, _) => self.execute_branch(instruction, current_pc, next_pc)
    Bgeu(_, _, _) => self.execute_branch(instruction, current_pc, next_pc)
    Lb(_, _, _) => self.execute_load(instruction, next_pc)
    Lh(_, _, _) => self.execute_load(instruction, next_pc)
    Lw(_, _, _) => self.execute_load(instruction, next_pc)
    Lwu(_, _, _) => self.execute_load(instruction, next_pc)
    Ld(_, _, _) => self.execute_load(instruction, next_pc)
    Lbu(_, _, _) => self.execute_load(instruction, next_pc)
    Lhu(_, _, _) => self.execute_load(instruction, next_pc)
    Flw(_, _, _) =>
      self.execute_fp_load_store(instruction, current_pc, next_pc, raw)
    Fld(_, _, _) =>
      self.execute_fp_load_store(instruction, current_pc, next_pc, raw)
    Sb(_, _, _) => self.execute_store(instruction, next_pc)
    Sh(_, _, _) => self.execute_store(instruction, next_pc)
    Sw(_, _, _) => self.execute_store(instruction, next_pc)
    Sd(_, _, _) => self.execute_store(instruction, next_pc)
    Fsw(_, _, _) =>
      self.execute_fp_load_store(instruction, current_pc, next_pc, raw)
    Fsd(_, _, _) =>
      self.execute_fp_load_store(instruction, current_pc, next_pc, raw)
    Jal(_, _) => self.execute_jump(instruction, current_pc, next_pc)
    Jalr(_, _, _) => self.execute_jump(instruction, current_pc, next_pc)
    Csrrw(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrs(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrc(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrwi(_, _, _) =>
      self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrsi(_, _, _) =>
      self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrci(_, _, _) =>
      self.execute_system(instruction, current_pc, next_pc, raw)
    SfenceVma(_, _) =>
      self.execute_system(instruction, current_pc, next_pc, raw)
    Wfi => self.execute_wfi(current_pc, next_pc, raw)
    AmoW(_, _, _, _) => self.execute_amo(instruction, current_pc, next_pc, raw)
    AmoD(_, _, _, _) => self.execute_amo(instruction, current_pc, next_pc, raw)
    FMAddS(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FMSubS(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FNMSubS(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FNMAddS(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FMAddD(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FMSubD(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FNMSubD(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FNMAddD(_, _, _, _, _) =>
      self.execute_fp(instruction, current_pc, next_pc, raw)
    FAddS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSubS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMulS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FDivS(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSqrtS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMinS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMaxS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSgnjS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSgnjnS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSgnjxS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FLeS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FLtS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FEqS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FClassS(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FAddD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSubD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMulD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FDivD(_, _, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSgnjD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSgnjnD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSgnjxD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FSqrtD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMinD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FMaxD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FLeD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FLtD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FEqD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FClassD(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvXW(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvWX(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvXD(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FmvDX(_, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtSD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtDS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtSW(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtSWU(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtSL(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtSLU(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtDW(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtDWU(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtDL(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtDLU(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtWS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtWUS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtLS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtLUS(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtWD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtWUD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtLD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    FCvtLUD(_, _, _) => self.execute_fp(instruction, current_pc, next_pc, raw)
    Vsetvli(_, _, _) => self.execute_vsetvl(instruction, next_pc)
    Vsetivli(_, _, _) => self.execute_vsetvl(instruction, next_pc)
    Vsetvl(_, _, _) => self.execute_vsetvl(instruction, next_pc)
    VmvVI(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmvVX(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmvVV(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmvXS(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmergeVvm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmergeVxm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmergeVim(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VaddVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VaddVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VaddVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsubVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsubVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VrsubVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VrsubVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwadduVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwadduVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwaddVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwaddVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwsubuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwsubuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwsubVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VwsubVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulhuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulhuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulhVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulhVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulhsuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmulhsuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VdivuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VdivuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VdivVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VdivVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VremuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VremuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VremVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VremVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VminuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VminuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VminVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VminVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmaxuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmaxuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmaxVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmaxVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmseqVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmseqVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmseqVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsneVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsneVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsneVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsltuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsltuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsltVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsltVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsleuVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsleuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsleuVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsleVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsleVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsleVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsgtuVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsgtuVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsgtVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsgtVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmandMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmnandMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmandnMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmxorMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmorMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmnorMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmornMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmxnorMm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VcpopM(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VfirstM(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsbfM(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsofM(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmsifM(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    ViotaM(_, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VidV(_) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VcompressVm(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VrgatherVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VrgatherVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VrgatherVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VslideupVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VslideupVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VslidedownVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VslidedownVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    Vslide1upVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    Vslide1downVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VmvNrR(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsllVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsllVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsllVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsrlVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsrlVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsrlVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsraVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsraVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VsraVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VandVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VandVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VandVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VorVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VorVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VorVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VxorVv(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VxorVx(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VxorVi(_, _, _) =>
      self.execute_vector_first_slice(instruction, current_pc, next_pc, raw)
    VlmV(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle8V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle16V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle32V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle64V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle8ffV(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle16ffV(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle32ffV(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vle64ffV(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vlseg2e32V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vluxei32V(_, _, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vloxei32V(_, _, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vlse32V(_, _, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vse8V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vse16V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vse32V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vse64V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vsseg2e32V(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vsuxei32V(_, _, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vsoxei32V(_, _, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Vsse32V(_, _, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    VsmV(_, _) =>
      self.execute_vector_memory_first_slice(
        instruction, current_pc, next_pc, raw,
      )
    Ecall => self.execute_system(instruction, current_pc, next_pc, raw)
    Ebreak => self.execute_system(instruction, current_pc, next_pc, raw)
    Mret => self.execute_system(instruction, current_pc, next_pc, raw)
    Sret => self.execute_system(instruction, current_pc, next_pc, raw)
    Unknown(_) => self.execute_system(instruction, current_pc, next_pc, raw)
  }
  match result {
    Running => self.increment_instret_counter(instret_inhibited_before_execute)
    _ => ()
  }
  result
}

///|
pub fn Runner::run(self : Runner, max_steps : Int) -> StepResult {
  for _ in 0..<max_steps {
    match self.step() {
      Running => ()
      result => return result
    }
  }
  Running
}

///|
pub fn words_to_bytes(words : Array[UInt]) -> Bytes {
  let bytes = []
  for index in 0..<words.length() {
    let word = words[index]
    bytes.push(word.to_byte())
    bytes.push((word >> 8).to_byte())
    bytes.push((word >> 16).to_byte())
    bytes.push((word >> 24).to_byte())
  }
  Bytes::from_array(bytes)
}

///|
pub fn demo_program_words() -> Array[UInt] {
  [0x00200093U, 0x00508113U, 0x002081b3U, 0x00302023U, 0x00002203U]
}
