// Vector integer move and merge helpers. These are separate from the arithmetic
// helpers because `vmerge` uses v0 as a selector over all body elements instead
// of treating mask-zero lanes as suppressed writes.

///|
fn Runner::execute_vector_move_vv(
  self : Runner,
  vd : Int,
  vs1 : Int,
  config : VectorExecConfig,
  active_elems : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  if !vector_group_aligned(vd, config.lmul_log2) ||
    !vector_group_aligned(vs1, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    self.write_vreg_group_elem(
      vd,
      elem,
      config.sew_bits,
      self.read_vreg_group_elem(vs1, elem, config.sew_bits),
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_merge_vv(
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
    !vector_group_aligned(vs2, config.lmul_log2) ||
    !vector_group_aligned(vs1, config.lmul_log2) {
    return self.raise_vector_group_misaligned(current_pc, raw)
  }
  for elem in 0..<active_elems {
    let source = if self.read_vmask_bit(elem) { vs1 } else { vs2 }
    self.write_vreg_group_elem(
      vd,
      elem,
      config.sew_bits,
      self.read_vreg_group_elem(source, elem, config.sew_bits),
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_merge_scalar(
  self : Runner,
  vd : Int,
  vs2 : Int,
  scalar : UInt64,
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
  for elem in 0..<active_elems {
    let value = if self.read_vmask_bit(elem) {
      scalar
    } else {
      self.read_vreg_group_elem(vs2, elem, config.sew_bits)
    }
    self.write_vreg_group_elem(vd, elem, config.sew_bits, value)
  }
  self.cpu.pc = next_pc
  Running
}
