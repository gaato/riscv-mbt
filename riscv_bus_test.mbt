// Bus backing-store characterization tests. These intentionally exercise only
// the public surface so the backing representation remains an implementation
// detail.

///|
fn bus_test_addr(base : UInt64, offset : Int) -> UInt64 {
  base + offset.reinterpret_as_uint().to_uint64()
}

///|
fn assert_bus_bytes(
  bus : @riscv_mbt.Bus,
  addr : UInt64,
  value : UInt64,
  width : Int,
) -> Unit raise {
  for index in 0..<width {
    assert_eq(
      bus.load_u8(bus_test_addr(addr, index)),
      (value >> (index * 8)) & 0xffU.to_uint64(),
    )
  }
}

///|
test "bus width round trips cover offsets zero through fifteen" {
  let base = 0x1000U.to_uint64()
  for offset in 0..<16 {
    let addr = bus_test_addr(base, offset)
    let byte_bus = @riscv_mbt.Bus::new(base, 32)
    let byte_value = (0x40 + offset).reinterpret_as_uint().to_uint64()
    byte_bus.store_u8(addr, byte_value)
    assert_eq(byte_bus.load_u8(addr), byte_value)
    assert_bus_bytes(byte_bus, addr, byte_value, 1)

    let half_bus = @riscv_mbt.Bus::new(base, 32)
    let half_value = 0xa15cU.to_uint64()
    half_bus.store_u16(addr, half_value)
    assert_eq(half_bus.load_u16(addr), half_value)
    assert_bus_bytes(half_bus, addr, half_value, 2)

    let word_bus = @riscv_mbt.Bus::new(base, 32)
    let word_value = 0xd36a9c25U.to_uint64()
    word_bus.store_u32(addr, word_value)
    assert_eq(word_bus.load_u32(addr), word_value)
    assert_bus_bytes(word_bus, addr, word_value, 4)

    let dword_bus = @riscv_mbt.Bus::new(base, 32)
    let dword_value = 0xf1d3b5976a4c2e08UL
    dword_bus.store_u64(addr, dword_value)
    assert_eq(dword_bus.load_u64(addr), dword_value)
    assert_bus_bytes(dword_bus, addr, dword_value, 8)
  }
}

///|
test "virtio read characterizes write_bytes_from source offset and zero fill" {
  let runner = @riscv_mbt.make_runner(@riscv_mbt.virtio_blk_machine_config())
  let desc_base = 0x80001000U.to_uint64()
  let avail_base = 0x80002000U.to_uint64()
  let used_base = 0x80003000U.to_uint64()
  let header_addr = 0x80004000U.to_uint64()
  let first_data_addr = 0x80004f00U.to_uint64()
  let data_addr = 0x80005001U.to_uint64()
  let status_addr = 0x80006000U.to_uint64()
  let disk = Array::make(519, 0U.to_byte())
  disk[512] = 0xa1U.to_byte()
  disk[513] = 0xb2U.to_byte()
  disk[514] = 0x19U.to_byte()
  disk[515] = 0x37U.to_byte()
  disk[516] = 0x5bU.to_byte()
  disk[517] = 0x7dU.to_byte()
  disk[518] = 0x9fU.to_byte()
  runner.load_virtio_blk_disk(Bytes::from_array(disk))
  runner.bus.store_u8(data_addr - 1U.to_uint64(), 0xa5U.to_uint64())
  for index in 0..<9 {
    runner.bus.store_u8(bus_test_addr(data_addr, index), 0xeeU.to_uint64())
  }
  runner.bus.store_u8(data_addr + 9U.to_uint64(), 0x5aU.to_uint64())
  runner.bus.store_u64(desc_base, header_addr)
  runner.bus.store_u32(desc_base + 8U.to_uint64(), 16U.to_uint64())
  runner.bus.store_u16(desc_base + 12U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 14U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u64(desc_base + 16U.to_uint64(), first_data_addr)
  runner.bus.store_u32(desc_base + 24U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u16(desc_base + 28U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(desc_base + 30U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u64(desc_base + 32U.to_uint64(), data_addr)
  runner.bus.store_u32(desc_base + 40U.to_uint64(), 9U.to_uint64())
  runner.bus.store_u16(desc_base + 44U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(desc_base + 46U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u64(desc_base + 48U.to_uint64(), status_addr)
  runner.bus.store_u32(desc_base + 56U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 60U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u32(header_addr, 0U.to_uint64())
  runner.bus.store_u64(header_addr + 8U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(avail_base + 2U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(avail_base + 4U.to_uint64(), 0U.to_uint64())
  runner.virtio_blk_state[4] = 8U.to_uint64()
  runner.virtio_blk_state[5] = 1U.to_uint64()
  runner.virtio_blk_state[8] = desc_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[9] = desc_base >> 32
  runner.virtio_blk_state[10] = avail_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[11] = avail_base >> 32
  runner.virtio_blk_state[12] = used_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[13] = used_base >> 32
  let program = @riscv_mbt.words_to_bytes([
    encode_u(0x10001000U, 5, 0x37U),
    encode_s(0x50, 0, 5, 0x2U, 0x23U),
  ])
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after odd-sized virtio-blk read")
  }
  let expected = [0x19U, 0x37U, 0x5bU, 0x7dU, 0x9fU, 0U, 0U, 0U, 0U]
  for index, byte in expected {
    assert_eq(
      runner.bus.load_u8(bus_test_addr(data_addr, index)),
      byte.to_uint64(),
    )
  }
  assert_eq(runner.bus.load_u8(data_addr - 1U.to_uint64()), 0xa5U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr + 9U.to_uint64()), 0x5aU.to_uint64())
}

///|
test "bus first and last bytes are addressable" {
  let base = 0x2000U.to_uint64()
  let bus = @riscv_mbt.Bus::new(base, 15)
  assert_eq(bus.size(), 15)
  bus.store_u8(base, 0x12U.to_uint64())
  bus.store_u8(base + 14U.to_uint64(), 0x34U.to_uint64())
  assert_eq(bus.load_u8(base), 0x12U.to_uint64())
  assert_eq(bus.load_u8(base + 14U.to_uint64()), 0x34U.to_uint64())
}

///|
test "panic bus rejects the byte one past the end" {
  let base = 0x2000U.to_uint64()
  let bus = @riscv_mbt.Bus::new(base, 15)
  ignore(bus.load_u8(base + 15U.to_uint64()))
}

///|
test "panic bus rejects a load straddling the end" {
  let base = 0x2000U.to_uint64()
  let bus = @riscv_mbt.Bus::new(base, 15)
  ignore(bus.load_u16(base + 14U.to_uint64()))
}

///|
test "zero_range crossing a word boundary preserves neighbours" {
  let base = 0x3000U.to_uint64()
  let bus = @riscv_mbt.Bus::new(base, 24)
  for index in 0..<24 {
    bus.store_u8(
      bus_test_addr(base, index),
      (index + 1).reinterpret_as_uint().to_uint64(),
    )
  }
  bus.zero_range(base + 6U.to_uint64(), 5)
  assert_eq(bus.load_u8(base + 5U.to_uint64()), 6U.to_uint64())
  for index in 6..<11 {
    assert_eq(bus.load_u8(bus_test_addr(base, index)), 0U.to_uint64())
  }
  assert_eq(bus.load_u8(base + 11U.to_uint64()), 12U.to_uint64())
}

///|
test "unaligned u16 reads characterize fetch halfword assembly" {
  let base = 0x4000U.to_uint64()
  let bus = @riscv_mbt.Bus::new(base, 24)
  for offset in [1, 3, 5, 7, 9, 11, 13, 15] {
    let addr = bus_test_addr(base, offset)
    bus.store_u8(addr, 0x5aU.to_uint64())
    bus.store_u8(addr + 1U.to_uint64(), 0xc3U.to_uint64())
    assert_eq(bus.load_u16(addr), 0xc35aU.to_uint64())
  }
}

///|
test "overlapping narrower load observes little endian stored bytes" {
  let base = 0x5000U.to_uint64()
  let bus = @riscv_mbt.Bus::new(base, 24)
  bus.store_u64(base + 5U.to_uint64(), 0xf1d3b5976a4c2e08UL)
  assert_eq(bus.load_u16(base + 8U.to_uint64()), 0x976aU.to_uint64())
}
