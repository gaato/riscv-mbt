// RVV permutation operations that rearrange vector register elements without
// touching memory. Keeping these out of `riscv_vector.mbt` leaves the main
// vector file focused on shared config, masks, arithmetic, and dispatch.

///|
fn Runner::execute_vector_permutation_dispatch(
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
) -> StepResult? {
  // This helper owns only permutation-style vector instructions that share the
  // standard element execution config. Whole-register moves are intentionally
  // handled before config creation because their NREG field is independent of
  // the current LMUL.
  match instruction {
    VcompressVm(vd, vs2, vs1) =>
      Some(
        self.execute_vector_compress(
          vd, vs2, vs1, config, active_elems, current_pc, next_pc, raw,
        ),
      )
    VrgatherVv(vd, vs2, vs1) =>
      Some(
        self.execute_vector_gather_vv(
          vd, vs2, vs1, config, active_elems, sew_mask, mask_bits, use_mask, current_pc,
          next_pc, raw,
        ),
      )
    VrgatherVx(vd, vs2, rs1) =>
      Some(
        self.execute_vector_gather_scalar(
          vd,
          vs2,
          self.cpu.read_reg(rs1),
          config,
          active_elems,
          sew_mask,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    VrgatherVi(vd, vs2, imm) =>
      Some(
        self.execute_vector_gather_scalar(
          vd,
          vs2,
          imm.to_uint64(),
          config,
          active_elems,
          sew_mask,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    VslideupVx(vd, vs2, rs1) =>
      Some(
        self.execute_vector_slideup(
          vd,
          vs2,
          self.cpu.read_reg(rs1),
          config,
          active_elems,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    VslideupVi(vd, vs2, imm) =>
      Some(
        self.execute_vector_slideup(
          vd,
          vs2,
          imm.to_uint64(),
          config,
          active_elems,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    VslidedownVx(vd, vs2, rs1) =>
      Some(
        self.execute_vector_slidedown(
          vd,
          vs2,
          self.cpu.read_reg(rs1),
          config,
          active_elems,
          sew_mask,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    VslidedownVi(vd, vs2, imm) =>
      Some(
        self.execute_vector_slidedown(
          vd,
          vs2,
          imm.to_uint64(),
          config,
          active_elems,
          sew_mask,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    Vslide1upVx(vd, vs2, rs1) =>
      Some(
        self.execute_vector_slide1up(
          vd,
          vs2,
          self.cpu.read_reg(rs1),
          config,
          active_elems,
          sew_mask,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    Vslide1downVx(vd, vs2, rs1) =>
      Some(
        self.execute_vector_slide1down(
          vd,
          vs2,
          self.cpu.read_reg(rs1),
          config,
          active_elems,
          sew_mask,
          mask_bits,
          use_mask,
          current_pc,
          next_pc,
          raw,
        ),
      )
    _ => None
  }
}

///|
fn Runner::execute_vector_compress(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  // `vcompress.vm` packs selected source elements into the front of the
  // destination group. Reject architecturally reserved overlaps so the source
  // vector and source mask are stable for the whole scan.
  if vector_group_contains_vreg(vd, config.lmul_log2, vs1) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let lmul_regs = vector_lmul_registers(config.lmul_log2)
  for reg in 0..<lmul_regs {
    if vector_group_contains_vreg(vd, config.lmul_log2, vs2 + reg) {
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
  }
  let mut dest_elem = 0
  for elem in 0..<active_elems {
    if self.read_vmask_bit_from(vs1, elem) {
      let value = self.read_vreg_group_elem(vs2, elem, config.sew_bits)
      self.write_vreg_group_elem(vd, dest_elem, config.sew_bits, value)
      dest_elem += 1
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn vector_vlmax(config : VectorExecConfig) -> Int {
  vector_elems_per_register(config.sew_bits) *
  vector_lmul_registers(config.lmul_log2)
}

///|
fn Runner::vector_gather_value(
  self : Runner,
  vs2 : Int,
  index : UInt64,
  config : VectorExecConfig,
) -> UInt64 {
  let vlmax = vector_vlmax(config).to_uint64()
  if index >= vlmax {
    0U.to_uint64()
  } else {
    self.read_vreg_group_elem(
      vs2,
      index.reinterpret_as_int64().to_int(),
      config.sew_bits,
    )
  }
}

///|
fn Runner::execute_vector_gather_vv(
  self : Runner,
  vd : Int,
  vs2 : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) ||
    !vector_group_aligned(vs1, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  // `vrgather.vv` treats both source operands as vector groups. The
  // destination must be disjoint so index reads and source data reads are not
  // clobbered while the gather is still in progress.
  let lmul_regs = vector_lmul_registers(config.lmul_log2)
  for reg in 0..<lmul_regs {
    if vector_group_contains_vreg(vd, config.lmul_log2, vs2 + reg) ||
      vector_group_contains_vreg(vd, config.lmul_log2, vs1 + reg) {
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      let index = self.read_vreg_group_elem(vs1, elem, config.sew_bits)
      self.write_vreg_group_elem(
        vd,
        elem,
        config.sew_bits,
        self.vector_gather_value(vs2, index, config) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_gather_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  index : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  let lmul_regs = vector_lmul_registers(config.lmul_log2)
  for reg in 0..<lmul_regs {
    if vector_group_contains_vreg(vd, config.lmul_log2, vs2 + reg) {
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
  }
  let value = self.vector_gather_value(vs2, index, config) & sew_mask
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      self.write_vreg_group_elem(vd, elem, config.sew_bits, value)
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn vector_group_overlaps(
  vd : Int,
  vs2 : Int,
  config : VectorExecConfig,
) -> Bool {
  let lmul_regs = vector_lmul_registers(config.lmul_log2)
  for reg in 0..<lmul_regs {
    if vector_group_contains_vreg(vd, config.lmul_log2, vs2 + reg) {
      return true
    }
  }
  false
}

///|
fn Runner::execute_vector_slideup(
  self : Runner,
  vd : Int,
  vs2 : Int,
  offset : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  // `vslideup` reads lower source elements while writing higher destination
  // elements, so the spec reserves destination/source overlap.
  if vector_group_overlaps(vd, vs2, config) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  for elem in 0..<active_elems {
    let elem_index = elem.reinterpret_as_uint().to_uint64()
    if elem_index >= offset && (!use_mask || mask_bits[elem]) {
      let source_elem = (elem_index - offset).reinterpret_as_int64().to_int()
      let value = self.read_vreg_group_elem(vs2, source_elem, config.sew_bits)
      self.write_vreg_group_elem(vd, elem, config.sew_bits, value)
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_slidedown(
  self : Runner,
  vd : Int,
  vs2 : Int,
  offset : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
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
      let source_index = elem.reinterpret_as_uint().to_uint64() + offset
      self.write_vreg_group_elem(
        vd,
        elem,
        config.sew_bits,
        self.vector_gather_value(vs2, source_index, config) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::vector_scalar_to_sew(
  self : Runner,
  scalar : UInt64,
  config : VectorExecConfig,
) -> UInt64 {
  let xlen = self.xlen_bits()
  let sew_mask = vector_elem_mask(config.sew_bits)
  if xlen < config.sew_bits {
    xlen_sign_extend(scalar, xlen, XLEN_64) & sew_mask
  } else {
    scalar & sew_mask
  }
}

///|
fn Runner::execute_vector_slide1up(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  // `vslide1up` is restartable only when destination writes cannot clobber
  // later source reads.
  if vector_group_overlaps(vd, vs2, config) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  if active_elems > 0 && (!use_mask || mask_bits[0]) {
    self.write_vreg_group_elem(
      vd,
      0,
      config.sew_bits,
      self.vector_scalar_to_sew(scalar, config),
    )
  }
  for elem in 1..<active_elems {
    if !use_mask || mask_bits[elem] {
      self.write_vreg_group_elem(
        vd,
        elem,
        config.sew_bits,
        self.read_vreg_group_elem(vs2, elem - 1, config.sew_bits) & sew_mask,
      )
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_slide1down(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
  config : VectorExecConfig,
  active_elems : Int,
  sew_mask : UInt64,
  mask_bits : Array[Bool],
  use_mask : Bool,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs2, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  // Overlap is legal for slide1down. Snapshot source results before writes so
  // in-place uses follow the architectural source-before-destination behavior.
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    let value = if elem == active_elems - 1 {
      self.vector_scalar_to_sew(scalar, config)
    } else {
      self.read_vreg_group_elem(vs2, elem + 1, config.sew_bits) & sew_mask
    }
    values.push(value)
  }
  for elem in 0..<active_elems {
    if !use_mask || mask_bits[elem] {
      self.write_vreg_group_elem(vd, elem, config.sew_bits, values[elem])
    }
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn vector_whole_group_aligned(vreg : Int, nreg : Int) -> Bool {
  vreg % nreg == 0 && vreg + nreg <= VREG_COUNT
}

///|
fn Runner::execute_vector_whole_register_move(
  self : Runner,
  vd : Int,
  vs2 : Int,
  nreg : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match self.vector_whole_register_move_supported() {
    Some(_) => ()
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  if !vector_whole_group_aligned(vd, nreg) ||
    !vector_whole_group_aligned(vs2, nreg) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  // Whole-register moves are byte-for-byte vector register copies. They are
  // intentionally independent of the current `vl`, and the encoded NREG
  // controls the group size instead of the current LMUL.
  for reg in 0..<nreg {
    for word in 0..<VREG_WORDS_PER_REG {
      self.cpu.write_vreg(vd + reg, word, self.cpu.read_vreg(vs2 + reg, word))
    }
  }
  self.cpu.pc = next_pc
  Running
}
