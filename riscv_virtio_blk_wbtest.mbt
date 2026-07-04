///|
test "virtio-blk write helper updates disk in place and invalidates read cache" {
  let runner = make_runner(virtio_blk_machine_config())
  let read_addr = 0x80005000U.to_uint64()
  let write_addr = 0x80006000U.to_uint64()
  runner.load_virtio_blk_disk(Bytes::make(1024, 0U.to_byte()))
  let first_read = runner.virtio_blk_copy_sector_to_guest(
    0U.to_uint64(),
    read_addr,
    4,
  )
  assert_eq(first_read, 4)
  assert_eq(runner.virtio_blk_read_cache_hit_count(), 0U.to_uint64())
  assert_eq(runner.virtio_blk_read_cache_miss_count(), 1U.to_uint64())
  runner.bus.store_u8(write_addr, 0x44U.to_uint64())
  runner.bus.store_u8(write_addr + 1U.to_uint64(), 0x55U.to_uint64())
  runner.bus.store_u8(write_addr + 2U.to_uint64(), 0x66U.to_uint64())
  runner.bus.store_u8(write_addr + 3U.to_uint64(), 0x77U.to_uint64())
  let written = runner.virtio_blk_copy_guest_to_sector(
    write_addr,
    0U.to_uint64(),
    4,
  )
  assert_eq(written, 4)
  assert_eq(
    runner.virtio_blk_read_cache_base,
    virtio_blk_read_cache_invalid_base,
  )
  assert_eq(runner.virtio_blk_disk_bytes()[0].to_uint64(), 0x44U.to_uint64())
  assert_eq(runner.virtio_blk_disk_bytes()[3].to_uint64(), 0x77U.to_uint64())
  let second_read = runner.virtio_blk_copy_sector_to_guest(
    0U.to_uint64(),
    read_addr,
    4,
  )
  assert_eq(second_read, 4)
  assert_eq(runner.virtio_blk_read_cache_hit_count(), 0U.to_uint64())
  assert_eq(runner.virtio_blk_read_cache_miss_count(), 2U.to_uint64())
  assert_eq(runner.bus.load_u8(read_addr), 0x44U.to_uint64())
  assert_eq(runner.bus.load_u8(read_addr + 3U.to_uint64()), 0x77U.to_uint64())
}
