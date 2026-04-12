
///|
fn bytes_load_u8(bytes : Bytes, offset : Int) -> UInt {
  bytes[offset].to_uint()
}

///|
fn bytes_load_u16(bytes : Bytes, offset : Int) -> UInt {
  bytes_load_u8(bytes, offset) |
  (bytes_load_u8(bytes, offset + 1) << 8)
}

///|
fn bytes_load_u32(bytes : Bytes, offset : Int) -> UInt {
  bytes_load_u8(bytes, offset) |
  (bytes_load_u8(bytes, offset + 1) << 8) |
  (bytes_load_u8(bytes, offset + 2) << 16) |
  (bytes_load_u8(bytes, offset + 3) << 24)
}

///|
fn bytes_load_u64(bytes : Bytes, offset : Int) -> UInt64 {
  bytes_load_u8(bytes, offset).to_uint64() |
  (bytes_load_u8(bytes, offset + 1).to_uint64() << 8) |
  (bytes_load_u8(bytes, offset + 2).to_uint64() << 16) |
  (bytes_load_u8(bytes, offset + 3).to_uint64() << 24) |
  (bytes_load_u8(bytes, offset + 4).to_uint64() << 32) |
  (bytes_load_u8(bytes, offset + 5).to_uint64() << 40) |
  (bytes_load_u8(bytes, offset + 6).to_uint64() << 48) |
  (bytes_load_u8(bytes, offset + 7).to_uint64() << 56)
}

///|
fn bytes_range_ok(bytes : Bytes, offset : Int, len : Int) -> Bool {
  offset >= 0 && len >= 0 && offset + len <= bytes.length()
}

///|
fn c_string_matches(
  bytes : Bytes,
  string_base : Int,
  name_offset : Int,
  expected : Array[Int],
) -> Bool {
  let mut index = 0
  while index < expected.length() {
    let current = string_base + name_offset + index
    if current >= bytes.length() || bytes[current].to_int() != expected[index] {
      return false
    }
    index = index + 1
  }
  let terminator = string_base + name_offset + expected.length()
  terminator < bytes.length() && bytes[terminator].to_int() == 0
}

///|
fn elf_symbol_matches(
  bytes : Bytes,
  string_base : Int,
  name_offset : UInt64,
  expected : Array[Int],
) -> Bool {
  c_string_matches(bytes, string_base, name_offset.reinterpret_as_int64().to_int(), expected)
}

///|
fn find_elf_symbol_addr(
  bytes : Bytes,
  symtab_offset : Int,
  symtab_size : Int,
  strtab_offset : Int,
  target_name : Array[Int],
  entry_size : Int,
  value_offset : Int,
  value_is_u64 : Bool,
) -> UInt64? {
  let mut index = 0
  while index + entry_size <= symtab_size {
    let entry_offset = symtab_offset + index
    let name_offset = bytes_load_u32(bytes, entry_offset).to_uint64()
    let value = if value_is_u64 {
      bytes_load_u64(bytes, entry_offset + value_offset)
    } else {
      bytes_load_u32(bytes, entry_offset + value_offset).to_uint64()
    }
    if elf_symbol_matches(bytes, strtab_offset, name_offset, target_name) {
      return Some(value)
    }
    index = index + entry_size
  }
  None
}

///|
fn read_elf_named_symbols(
  bytes : Bytes,
  symtab_offset : Int,
  symtab_size : Int,
  strtab_offset : Int,
  entry_size : Int,
  value_offset : Int,
  value_is_u64 : Bool,
) -> (UInt64?, UInt64?, UInt64?, UInt64?) {
  let tohost = find_elf_symbol_addr(
    bytes,
    symtab_offset,
    symtab_size,
    strtab_offset,
    [116, 111, 104, 111, 115, 116],
    entry_size,
    value_offset,
    value_is_u64,
  )
  let fromhost = find_elf_symbol_addr(
    bytes,
    symtab_offset,
    symtab_size,
    strtab_offset,
    [102, 114, 111, 109, 104, 111, 115, 116],
    entry_size,
    value_offset,
    value_is_u64,
  )
  let begin_signature = find_elf_symbol_addr(
    bytes,
    symtab_offset,
    symtab_size,
    strtab_offset,
    [98, 101, 103, 105, 110, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
    entry_size,
    value_offset,
    value_is_u64,
  )
  let end_signature = find_elf_symbol_addr(
    bytes,
    symtab_offset,
    symtab_size,
    strtab_offset,
    [101, 110, 100, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
    entry_size,
    value_offset,
    value_is_u64,
  )
  (tohost, fromhost, begin_signature, end_signature)
}

///|
fn parse_elf32_symbols(
  bytes : Bytes,
  shoff : Int,
  shentsize : Int,
  shnum : Int,
) -> (UInt64?, UInt64?, UInt64?, UInt64?) {
  let mut index = 0
  while index < shnum {
    let sh_offset = shoff + (index * shentsize)
    let sh_type = bytes_load_u32(bytes, sh_offset + 4)
    if sh_type == 2U {
      let symtab_offset = bytes_load_u32(bytes, sh_offset + 16).reinterpret_as_int()
      let symtab_size = bytes_load_u32(bytes, sh_offset + 20).reinterpret_as_int()
      let strtab_index = bytes_load_u32(bytes, sh_offset + 24).reinterpret_as_int()
      let strtab_header = shoff + (strtab_index * shentsize)
      let strtab_offset = bytes_load_u32(bytes, strtab_header + 16).reinterpret_as_int()
      if bytes_range_ok(bytes, symtab_offset, symtab_size) {
        return read_elf_named_symbols(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          16,
          4,
          false,
        )
      }
    }
    index = index + 1
  }
  (None, None, None, None)
}

///|
fn parse_elf64_symbols(
  bytes : Bytes,
  shoff : Int,
  shentsize : Int,
  shnum : Int,
) -> (UInt64?, UInt64?, UInt64?, UInt64?) {
  let mut index = 0
  while index < shnum {
    let sh_offset = shoff + (index * shentsize)
    let sh_type = bytes_load_u32(bytes, sh_offset + 4)
    if sh_type == 2U {
      let symtab_offset = bytes_load_u64(bytes, sh_offset + 24).reinterpret_as_int64().to_int()
      let symtab_size = bytes_load_u64(bytes, sh_offset + 32).reinterpret_as_int64().to_int()
      let strtab_index = bytes_load_u32(bytes, sh_offset + 40).reinterpret_as_int()
      let strtab_header = shoff + (strtab_index * shentsize)
      let strtab_offset = bytes_load_u64(bytes, strtab_header + 24).reinterpret_as_int64().to_int()
      if bytes_range_ok(bytes, symtab_offset, symtab_size) {
        return read_elf_named_symbols(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          24,
          8,
          true,
        )
      }
    }
    index = index + 1
  }
  (None, None, None, None)
}

///|
fn Runner::load_elf_segment(
  self : Runner,
  bytes : Bytes,
  file_offset : Int,
  file_size : Int,
  virtual_addr : UInt64,
  mem_size : Int,
) -> String? {
  if !bytes_range_ok(bytes, file_offset, file_size) {
    return Some("segment data is truncated")
  }
  if !self.bus.contains_range(virtual_addr, mem_size) {
    return Some("segment does not fit in configured RAM")
  }
  let mut byte_index = 0
  while byte_index < file_size {
    self.bus.store_u8(
      virtual_addr + byte_index.reinterpret_as_uint().to_uint64(),
      bytes[file_offset + byte_index].to_uint().to_uint64(),
    )
    byte_index = byte_index + 1
  }
  if mem_size > file_size {
    self.bus.zero_range(
      virtual_addr + file_size.reinterpret_as_uint().to_uint64(),
      mem_size - file_size,
    )
  }
  None
}

///|
pub fn Runner::load_elf(self : Runner, bytes : Bytes) -> LoadElfResult {
  if !bytes_range_ok(bytes, 0, 52) {
    return LoadError("ELF header is truncated")
  }
  if bytes[0].to_int() != 0x7f ||
    bytes[1].to_int() != 0x45 ||
    bytes[2].to_int() != 0x4c ||
    bytes[3].to_int() != 0x46 {
    return LoadError("invalid ELF magic")
  }
  if bytes[5].to_int() != 1 {
    return LoadError("only little-endian ELF is supported")
  }
  if bytes_load_u16(bytes, 18) != 243U {
    return LoadError("ELF is not for RISC-V")
  }

  match bytes[4].to_int() {
    1 => {
      let entry_point = bytes_load_u32(bytes, 24).to_uint64()
      let phoff = bytes_load_u32(bytes, 28).reinterpret_as_int()
      let shoff = bytes_load_u32(bytes, 32).reinterpret_as_int()
      let phentsize = bytes_load_u16(bytes, 42).reinterpret_as_int()
      let phnum = bytes_load_u16(bytes, 44).reinterpret_as_int()
      let shentsize = bytes_load_u16(bytes, 46).reinterpret_as_int()
      let shnum = bytes_load_u16(bytes, 48).reinterpret_as_int()

      let mut ph_index = 0
      while ph_index < phnum {
        let ph_offset = phoff + (ph_index * phentsize)
        if !bytes_range_ok(bytes, ph_offset, phentsize) {
          return LoadError("program header is truncated")
        }
        if bytes_load_u32(bytes, ph_offset) == 1U {
          let file_offset = bytes_load_u32(bytes, ph_offset + 4).reinterpret_as_int()
          let virtual_addr = bytes_load_u32(bytes, ph_offset + 8).to_uint64()
          let file_size = bytes_load_u32(bytes, ph_offset + 16).reinterpret_as_int()
          let mem_size = bytes_load_u32(bytes, ph_offset + 20).reinterpret_as_int()
          match self.load_elf_segment(bytes, file_offset, file_size, virtual_addr, mem_size) {
            Some(message) => return LoadError(message)
            None => ()
          }
        }
        ph_index = ph_index + 1
      }

      let (tohost, fromhost, begin_signature, end_signature) = if shoff != 0 &&
        shentsize >= 40 && shnum > 0 {
        parse_elf32_symbols(bytes, shoff, shentsize, shnum)
      } else {
        (None, None, None, None)
      }

      self.cpu.pc = entry_point
      Loaded({
        entry_point,
        tohost_addr: tohost,
        fromhost_addr: fromhost,
        begin_signature_addr: begin_signature,
        end_signature_addr: end_signature,
      })
    }
    2 => {
      if !bytes_range_ok(bytes, 0, 64) {
        return LoadError("ELF header is truncated")
      }
      let entry_point = bytes_load_u64(bytes, 24)
      let phoff = bytes_load_u64(bytes, 32).reinterpret_as_int64().to_int()
      let shoff = bytes_load_u64(bytes, 40).reinterpret_as_int64().to_int()
      let phentsize = bytes_load_u16(bytes, 54).reinterpret_as_int()
      let phnum = bytes_load_u16(bytes, 56).reinterpret_as_int()
      let shentsize = bytes_load_u16(bytes, 58).reinterpret_as_int()
      let shnum = bytes_load_u16(bytes, 60).reinterpret_as_int()

      let mut ph_index = 0
      while ph_index < phnum {
        let ph_offset = phoff + (ph_index * phentsize)
        if !bytes_range_ok(bytes, ph_offset, phentsize) {
          return LoadError("program header is truncated")
        }
        if bytes_load_u32(bytes, ph_offset) == 1U {
          let file_offset = bytes_load_u64(bytes, ph_offset + 8).reinterpret_as_int64().to_int()
          let virtual_addr = bytes_load_u64(bytes, ph_offset + 16)
          let file_size = bytes_load_u64(bytes, ph_offset + 32).reinterpret_as_int64().to_int()
          let mem_size = bytes_load_u64(bytes, ph_offset + 40).reinterpret_as_int64().to_int()
          match self.load_elf_segment(bytes, file_offset, file_size, virtual_addr, mem_size) {
            Some(message) => return LoadError(message)
            None => ()
          }
        }
        ph_index = ph_index + 1
      }

      let (tohost, fromhost, begin_signature, end_signature) = if shoff != 0 &&
        shentsize >= 64 && shnum > 0 {
        parse_elf64_symbols(bytes, shoff, shentsize, shnum)
      } else {
        (None, None, None, None)
      }

      self.cpu.pc = entry_point
      Loaded({
        entry_point,
        tohost_addr: tohost,
        fromhost_addr: fromhost,
        begin_signature_addr: begin_signature,
        end_signature_addr: end_signature,
      })
    }
    _ => LoadError("only ELF32 and ELF64 are supported")
  }
}

///|
