///|
let virtio_mmio_magic : UInt64 = 0x74726976U.to_uint64()

///|
let virtio_mmio_version : UInt64 = 2U.to_uint64()

///|
let virtio_blk_device_id : UInt64 = 2U.to_uint64()

///|
let virtio_vendor_riscv_mbt : UInt64 = 0x6d6274U.to_uint64()

///|
let virtio_blk_queue_max : UInt64 = 8U.to_uint64()

///|
let virtio_blk_capacity_sectors : UInt64 = 2048U.to_uint64()

///|
let virtio_blk_idx_device_features_sel : Int = 0

///|
let virtio_blk_idx_driver_features : Int = 1

///|
let virtio_blk_idx_driver_features_sel : Int = 2

///|
let virtio_blk_idx_queue_sel : Int = 3

///|
let virtio_blk_idx_queue_num : Int = 4

///|
let virtio_blk_idx_queue_ready : Int = 5

///|
let virtio_blk_idx_interrupt_status : Int = 6

///|
let virtio_blk_idx_status : Int = 7

///|
let virtio_blk_idx_queue_desc_lo : Int = 8

///|
let virtio_blk_idx_queue_desc_hi : Int = 9

///|
let virtio_blk_idx_queue_driver_lo : Int = 10

///|
let virtio_blk_idx_queue_driver_hi : Int = 11

///|
let virtio_blk_idx_queue_device_lo : Int = 12

///|
let virtio_blk_idx_queue_device_hi : Int = 13

///|
fn Runner::virtio_blk_read_u32(self : Runner, off : UInt64) -> UInt64 {
  // This first slice exposes the Linux-visible MMIO transport identity and
  // queue configuration registers. Request processing is added in a later
  // slice; until then QueueNotify is intentionally inert.
  match off {
    0x000 => virtio_mmio_magic
    0x004 => virtio_mmio_version
    0x008 => virtio_blk_device_id
    0x00c => virtio_vendor_riscv_mbt
    0x010 => 0U.to_uint64()
    0x014 => self.virtio_blk_state[virtio_blk_idx_device_features_sel]
    0x020 => self.virtio_blk_state[virtio_blk_idx_driver_features]
    0x024 => self.virtio_blk_state[virtio_blk_idx_driver_features_sel]
    0x030 => self.virtio_blk_state[virtio_blk_idx_queue_sel]
    0x034 =>
      if self.virtio_blk_state[virtio_blk_idx_queue_sel] == 0U.to_uint64() {
        virtio_blk_queue_max
      } else {
        0U.to_uint64()
      }
    0x038 => self.virtio_blk_state[virtio_blk_idx_queue_num]
    0x044 => self.virtio_blk_state[virtio_blk_idx_queue_ready]
    0x060 => self.virtio_blk_state[virtio_blk_idx_interrupt_status]
    0x070 => self.virtio_blk_state[virtio_blk_idx_status]
    0x080 => self.virtio_blk_state[virtio_blk_idx_queue_desc_lo]
    0x084 => self.virtio_blk_state[virtio_blk_idx_queue_desc_hi]
    0x090 => self.virtio_blk_state[virtio_blk_idx_queue_driver_lo]
    0x094 => self.virtio_blk_state[virtio_blk_idx_queue_driver_hi]
    0x0a0 => self.virtio_blk_state[virtio_blk_idx_queue_device_lo]
    0x0a4 => self.virtio_blk_state[virtio_blk_idx_queue_device_hi]
    0x0fc => 0U.to_uint64()
    0x100 => virtio_blk_capacity_sectors & 0xffffffffU.to_uint64()
    0x104 => virtio_blk_capacity_sectors >> 32
    _ => 0U.to_uint64()
  }
}

///|
fn Runner::virtio_blk_reset(self : Runner) -> Unit {
  for index in 0..<self.virtio_blk_state.length() {
    self.virtio_blk_state[index] = 0U.to_uint64()
  }
}

///|
fn Runner::virtio_blk_write_u32(
  self : Runner,
  off : UInt64,
  value : UInt64,
) -> Unit {
  let value32 = value & 0xffffffffU.to_uint64()
  match off {
    0x014 => self.virtio_blk_state[virtio_blk_idx_device_features_sel] = value32
    0x020 => self.virtio_blk_state[virtio_blk_idx_driver_features] = value32
    0x024 => self.virtio_blk_state[virtio_blk_idx_driver_features_sel] = value32
    0x030 => self.virtio_blk_state[virtio_blk_idx_queue_sel] = value32
    0x038 => self.virtio_blk_state[virtio_blk_idx_queue_num] = value32
    0x044 =>
      self.virtio_blk_state[virtio_blk_idx_queue_ready] = value32 &
        1U.to_uint64()
    0x060 => ()
    0x064 =>
      self.virtio_blk_state[virtio_blk_idx_interrupt_status] = self.virtio_blk_state[virtio_blk_idx_interrupt_status] &
        bit_not(value32)
    0x070 =>
      if value32 == 0U.to_uint64() {
        self.virtio_blk_reset()
      } else {
        self.virtio_blk_state[virtio_blk_idx_status] = value32
      }
    0x080 => self.virtio_blk_state[virtio_blk_idx_queue_desc_lo] = value32
    0x084 => self.virtio_blk_state[virtio_blk_idx_queue_desc_hi] = value32
    0x090 => self.virtio_blk_state[virtio_blk_idx_queue_driver_lo] = value32
    0x094 => self.virtio_blk_state[virtio_blk_idx_queue_driver_hi] = value32
    0x0a0 => self.virtio_blk_state[virtio_blk_idx_queue_device_lo] = value32
    0x0a4 => self.virtio_blk_state[virtio_blk_idx_queue_device_hi] = value32
    _ => ()
  }
}
