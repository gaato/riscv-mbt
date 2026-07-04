// Vector memory execution helpers. Keep load/store legality and no-partial-commit
// behavior here so arithmetic, compare, and future mask operations stay focused.

///|
fn Runner::vector_memory_exec_config(self : Runner) -> VectorExecConfig? {
  match self.current_vector_exec_config() {
    Some(config) =>
      if config.lmul_log2 <= 3 &&
        self.cpu.read_csr(CSR_VSTART) == 0U.to_uint64() {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn Runner::vector_memory_group_config(
  self : Runner,
  vreg : Int,
  elem_bytes : Int,
) -> VectorExecConfig? {
  match self.vector_memory_exec_config() {
    Some(config) =>
      if config.sew_bits == elem_bytes * 8 &&
        vector_group_aligned(vreg, config.lmul_log2) {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn vector_segment_field_vreg(
  base_vreg : Int,
  field : Int,
  lmul_log2 : Int,
) -> Int {
  base_vreg + field * vector_lmul_registers(lmul_log2)
}

///|
fn vector_segment_group_aligned(
  base_vreg : Int,
  field_count : Int,
  lmul_log2 : Int,
) -> Bool {
  for field in 0..<field_count {
    if !vector_group_aligned(
        vector_segment_field_vreg(base_vreg, field, lmul_log2),
        lmul_log2,
      ) {
      return false
    }
  }
  true
}

///|
fn Runner::vector_segment_memory_config(
  self : Runner,
  base_vreg : Int,
  elem_bytes : Int,
  field_count : Int,
) -> VectorExecConfig? {
  match self.vector_memory_exec_config() {
    Some(config) =>
      if config.sew_bits == elem_bytes * 8 &&
        vector_segment_group_aligned(base_vreg, field_count, config.lmul_log2) {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn Runner::vector_mask_memory_config(self : Runner) -> VectorExecConfig? {
  match self.current_vector_exec_config() {
    Some(config) =>
      if self.cpu.read_csr(CSR_VSTART) == 0U.to_uint64() {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn vector_mask_memory_bytes(vl : UInt64) -> Int {
  ((vl + 7U.to_uint64()) / 8U.to_uint64()).reinterpret_as_int64().to_int()
}

///|
fn Runner::vector_indexed_e32_config(
  self : Runner,
  data_vreg : Int,
  index_vreg : Int,
) -> VectorExecConfig? {
  match self.vector_memory_group_config(data_vreg, 4) {
    Some(config) =>
      // This first indexed slice supports only data SEW=32 with index EEW=32,
      // so the index EMUL matches the current LMUL.
      if config.sew_bits == 32 &&
        vector_group_aligned(index_vreg, config.lmul_log2) {
        Some(config)
      } else {
        None
      }
    None => None
  }
}

///|
fn vector_unit_stride_addr(
  base : UInt64,
  elem_index : Int,
  elem_bytes : Int,
) -> UInt64 {
  base +
  elem_index.reinterpret_as_uint().to_uint64() *
  elem_bytes.reinterpret_as_uint().to_uint64()
}

///|
fn vector_strided_addr(
  base : UInt64,
  elem_index : Int,
  stride : UInt64,
) -> UInt64 {
  base + elem_index.reinterpret_as_uint().to_uint64() * stride
}

///|
fn vector_indexed_addr(base : UInt64, offset : UInt64) -> UInt64 {
  base + offset
}

///|
fn vector_segment_unit_stride_addr(
  base : UInt64,
  elem_index : Int,
  field : Int,
  field_count : Int,
  elem_bytes : Int,
) -> UInt64 {
  base +
  ((elem_index * field_count + field) * elem_bytes)
  .reinterpret_as_uint()
  .to_uint64()
}

///|
fn vector_memory_uses_mask(raw : UInt) -> Bool {
  ((raw >> 25) & 0x1U) == 0U
}

///|
// Masked vector memory instructions must not touch memory for inactive lanes.
// This is checked before address translation so inactive invalid addresses do
// not fault and masked loads preserve their old destination elements.
fn Runner::vector_memory_elem_active(
  self : Runner,
  raw : UInt,
  elem : Int,
) -> Bool {
  !vector_memory_uses_mask(raw) || self.read_vmask_bit(elem)
}

///|
fn Runner::vector_load_elem_bits(
  self : Runner,
  pa : UInt64,
  elem_bytes : Int,
) -> UInt64 {
  match elem_bytes {
    1 => self.phy_load_u8(pa)
    2 => self.phy_load_u16(pa)
    4 => self.phy_load_u32(pa)
    8 => self.phy_load_u64(pa)
    _ => abort("unsupported vector load element width")
  }
}

///|
fn Runner::vector_store_elem_bits(
  self : Runner,
  pa : UInt64,
  elem_bytes : Int,
  value : UInt64,
) -> Unit {
  match elem_bytes {
    1 => self.phy_store_u8(pa, value)
    2 => self.phy_store_u16(pa, value)
    4 => self.phy_store_u32(pa, value)
    8 => self.phy_store_u64(pa, value)
    _ => abort("unsupported vector store element width")
  }
}

///|
fn Runner::execute_vector_load_unit_stride(
  self : Runner,
  vd : Int,
  rs1 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vd, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let elems : Array[Int] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      let addr = vector_unit_stride_addr(base, elem, elem_bytes)
      let (pa, check) = self.load_check(addr, elem_bytes)
      match check {
        Some(result) => return result
        None => {
          elems.push(elem)
          pas.push(pa)
        }
      }
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_index in 0..<elems.length() {
    self.write_vreg_group_elem(
      vd,
      elems[commit_index],
      sew_bits,
      values[commit_index],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_load_unit_stride_segment(
  self : Runner,
  vd : Int,
  rs1 : Int,
  field_count : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match
    self.vector_segment_memory_config(vd, elem_bytes, field_count) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let elems : Array[Int] = []
  let fields : Array[Int] = []
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  // Unit-stride segment memory is laid out as packed structures:
  // element0.field0, element0.field1, element1.field0, ...
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      for field in 0..<field_count {
        let addr = vector_segment_unit_stride_addr(
          base, elem, field, field_count, elem_bytes,
        )
        let (pa, check) = self.load_check(addr, elem_bytes)
        match check {
          Some(result) => return result
          None => {
            elems.push(elem)
            fields.push(field)
            pas.push(pa)
          }
        }
      }
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_index in 0..<pas.length() {
    let field_vreg = vector_segment_field_vreg(
      vd,
      fields[commit_index],
      config.lmul_log2,
    )
    self.write_vreg_group_elem(
      field_vreg,
      elems[commit_index],
      sew_bits,
      values[commit_index],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_load_fault_only_first(
  self : Runner,
  vd : Int,
  rs1 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vd, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let original_vl = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let values : Array[UInt64] = []
  let elems : Array[Int] = []
  let mut committed_elems = original_vl
  // Fault-only-first loads trap only for element zero. Later synchronous faults
  // trim vl to the faulting element and commit the prefix already loaded.
  for elem in 0..<original_vl {
    if self.vector_memory_elem_active(raw, elem) {
      let addr = vector_unit_stride_addr(base, elem, elem_bytes)
      let (pa, check) = self.load_check(addr, elem_bytes)
      match check {
        Some(result) =>
          if elem == 0 {
            return result
          } else {
            committed_elems = elem
            break
          }
        None => {
          elems.push(elem)
          values.push(self.vector_load_elem_bits(pa, elem_bytes))
        }
      }
    }
  }
  for commit_index in 0..<elems.length() {
    if elems[commit_index] < committed_elems {
      self.write_vreg_group_elem(
        vd,
        elems[commit_index],
        sew_bits,
        values[commit_index],
      )
    }
  }
  if committed_elems < original_vl {
    self.cpu.write_csr(
      CSR_VL,
      committed_elems.reinterpret_as_uint().to_uint64(),
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_load_strided(
  self : Runner,
  vd : Int,
  rs1 : Int,
  rs2 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vd, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let stride = self.cpu.read_reg(rs2)
  let pas : Array[UInt64] = []
  let elems : Array[Int] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      let addr = vector_strided_addr(base, elem, stride)
      let (pa, check) = self.load_check(addr, elem_bytes)
      match check {
        Some(result) => return result
        None => {
          elems.push(elem)
          pas.push(pa)
        }
      }
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_index in 0..<elems.length() {
    self.write_vreg_group_elem(
      vd,
      elems[commit_index],
      sew_bits,
      values[commit_index],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_load_indexed_e32(
  self : Runner,
  vd : Int,
  rs1 : Int,
  vs2 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_indexed_e32_config(vd, vs2) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let elem_bytes = 4
  let sew_bits = 32
  let index_bits = 32
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let elems : Array[Int] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      let offset = self.read_vreg_group_elem(vs2, elem, index_bits)
      let addr = vector_indexed_addr(base, offset)
      let (pa, check) = self.load_check(addr, elem_bytes)
      match check {
        Some(result) => return result
        None => {
          elems.push(elem)
          pas.push(pa)
        }
      }
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, elem_bytes))
  }
  for commit_index in 0..<elems.length() {
    self.write_vreg_group_elem(
      vd,
      elems[commit_index],
      sew_bits,
      values[commit_index],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_load(
  self : Runner,
  vd : Int,
  rs1 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_mask_memory_config() {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let active_bytes = vector_mask_memory_bytes(config.vl)
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_bytes {
    let addr = vector_unit_stride_addr(base, elem, 1)
    let (pa, check) = self.load_check(addr, 1)
    match check {
      Some(result) => return result
      None => pas.push(pa)
    }
  }
  for pa in pas {
    values.push(self.vector_load_elem_bits(pa, 1))
  }
  for commit_elem in 0..<active_bytes {
    self.write_vreg_elem(vd, commit_elem, 8, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_unit_stride(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vs3, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      let addr = vector_unit_stride_addr(base, elem, elem_bytes)
      let (pa, check) = self.store_check(addr, elem_bytes)
      match check {
        Some(result) => return result
        None => {
          pas.push(pa)
          values.push(self.read_vreg_group_elem(vs3, elem, sew_bits))
        }
      }
    }
  }
  for commit_elem in 0..<pas.length() {
    self.vector_store_elem_bits(
      pas[commit_elem],
      elem_bytes,
      values[commit_elem],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_unit_stride_segment(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  field_count : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match
    self.vector_segment_memory_config(vs3, elem_bytes, field_count) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      for field in 0..<field_count {
        let addr = vector_segment_unit_stride_addr(
          base, elem, field, field_count, elem_bytes,
        )
        let (pa, check) = self.store_check(addr, elem_bytes)
        match check {
          Some(result) => return result
          None => {
            let field_vreg = vector_segment_field_vreg(
              vs3,
              field,
              config.lmul_log2,
            )
            pas.push(pa)
            values.push(self.read_vreg_group_elem(field_vreg, elem, sew_bits))
          }
        }
      }
    }
  }
  for commit_index in 0..<pas.length() {
    self.vector_store_elem_bits(
      pas[commit_index],
      elem_bytes,
      values[commit_index],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_mask_store(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_mask_memory_config() {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let active_bytes = vector_mask_memory_bytes(config.vl)
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_bytes {
    let addr = vector_unit_stride_addr(base, elem, 1)
    let (pa, check) = self.store_check(addr, 1)
    match check {
      Some(result) => return result
      None => {
        pas.push(pa)
        values.push(self.read_vreg_elem(vs3, elem, 8))
      }
    }
  }
  for commit_elem in 0..<active_bytes {
    self.vector_store_elem_bits(pas[commit_elem], 1, values[commit_elem])
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_indexed_e32(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  vs2 : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_indexed_e32_config(vs3, vs2) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let elem_bytes = 4
  let sew_bits = 32
  let index_bits = 32
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      let offset = self.read_vreg_group_elem(vs2, elem, index_bits)
      let addr = vector_indexed_addr(base, offset)
      let (pa, check) = self.store_check(addr, elem_bytes)
      match check {
        Some(result) => return result
        None => {
          pas.push(pa)
          values.push(self.read_vreg_group_elem(vs3, elem, sew_bits))
        }
      }
    }
  }
  for commit_elem in 0..<pas.length() {
    self.vector_store_elem_bits(
      pas[commit_elem],
      elem_bytes,
      values[commit_elem],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_store_strided(
  self : Runner,
  vs3 : Int,
  rs1 : Int,
  rs2 : Int,
  elem_bytes : Int,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let config = match self.vector_memory_group_config(vs3, elem_bytes) {
    Some(config) => config
    None =>
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  let sew_bits = elem_bytes * 8
  let active_elems = config.vl.reinterpret_as_int64().to_int()
  let base = self.cpu.read_reg(rs1)
  let stride = self.cpu.read_reg(rs2)
  let pas : Array[UInt64] = []
  let values : Array[UInt64] = []
  for elem in 0..<active_elems {
    if self.vector_memory_elem_active(raw, elem) {
      let addr = vector_strided_addr(base, elem, stride)
      let (pa, check) = self.store_check(addr, elem_bytes)
      match check {
        Some(result) => return result
        None => {
          pas.push(pa)
          values.push(self.read_vreg_group_elem(vs3, elem, sew_bits))
        }
      }
    }
  }
  for commit_elem in 0..<pas.length() {
    self.vector_store_elem_bits(
      pas[commit_elem],
      elem_bytes,
      values[commit_elem],
    )
  }
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_vector_memory_first_slice(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    VlmV(vd, rs1) =>
      self.execute_vector_mask_load(vd, rs1, current_pc, next_pc, raw)
    Vle8V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 1, current_pc, next_pc, raw)
    Vle16V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 2, current_pc, next_pc, raw)
    Vle32V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 4, current_pc, next_pc, raw)
    Vle64V(vd, rs1) =>
      self.execute_vector_load_unit_stride(vd, rs1, 8, current_pc, next_pc, raw)
    Vle8ffV(vd, rs1) =>
      self.execute_vector_load_fault_only_first(
        vd, rs1, 1, current_pc, next_pc, raw,
      )
    Vle16ffV(vd, rs1) =>
      self.execute_vector_load_fault_only_first(
        vd, rs1, 2, current_pc, next_pc, raw,
      )
    Vle32ffV(vd, rs1) =>
      self.execute_vector_load_fault_only_first(
        vd, rs1, 4, current_pc, next_pc, raw,
      )
    Vle64ffV(vd, rs1) =>
      self.execute_vector_load_fault_only_first(
        vd, rs1, 8, current_pc, next_pc, raw,
      )
    Vlseg2e32V(vd, rs1) =>
      self.execute_vector_load_unit_stride_segment(
        vd, rs1, 2, 4, current_pc, next_pc, raw,
      )
    Vluxei32V(vd, rs1, vs2) =>
      self.execute_vector_load_indexed_e32(
        vd, rs1, vs2, current_pc, next_pc, raw,
      )
    Vloxei32V(vd, rs1, vs2) =>
      self.execute_vector_load_indexed_e32(
        vd, rs1, vs2, current_pc, next_pc, raw,
      )
    Vlse32V(vd, rs1, rs2) =>
      self.execute_vector_load_strided(
        vd, rs1, rs2, 4, current_pc, next_pc, raw,
      )
    VsmV(vs3, rs1) =>
      self.execute_vector_mask_store(vs3, rs1, current_pc, next_pc, raw)
    Vse8V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 1, current_pc, next_pc, raw,
      )
    Vse16V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 2, current_pc, next_pc, raw,
      )
    Vse32V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 4, current_pc, next_pc, raw,
      )
    Vse64V(vs3, rs1) =>
      self.execute_vector_store_unit_stride(
        vs3, rs1, 8, current_pc, next_pc, raw,
      )
    Vsseg2e32V(vs3, rs1) =>
      self.execute_vector_store_unit_stride_segment(
        vs3, rs1, 2, 4, current_pc, next_pc, raw,
      )
    Vsuxei32V(vs3, rs1, vs2) =>
      self.execute_vector_store_indexed_e32(
        vs3, rs1, vs2, current_pc, next_pc, raw,
      )
    Vsoxei32V(vs3, rs1, vs2) =>
      self.execute_vector_store_indexed_e32(
        vs3, rs1, vs2, current_pc, next_pc, raw,
      )
    Vsse32V(vs3, rs1, rs2) =>
      self.execute_vector_store_strided(
        vs3, rs1, rs2, 4, current_pc, next_pc, raw,
      )
    _ => abort("unexpected vector memory first-slice dispatch")
  }
}
