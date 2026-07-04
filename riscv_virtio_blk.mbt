// Minimal virtio-mmio block device model for the Alpine full-rootfs path.
// Keep this file focused on the transport/register contract and split
// virtqueue request handling; platform interrupt wiring lives in
// `riscv_platform.mbt`, and Linux-facing validation lives in `cmd/alpine_probe`.

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
let virtio_blk_read_cache_invalid_base : UInt64 = bit_not(0U.to_uint64())

///|
let virtio_blk_read_ahead_bytes : Int = 65536

///|
let virtio_feature_version_1_page : UInt64 = 1U.to_uint64()

///|
let virtio_feature_version_1_mask : UInt64 = 1U.to_uint64()

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
let virtio_blk_idx_last_avail : Int = 14

///|
let virtq_desc_f_next : UInt64 = 1U.to_uint64()

///|
let virtq_desc_f_write : UInt64 = 2U.to_uint64()

///|
let virtio_blk_t_in : UInt64 = 0U.to_uint64()

///|
let virtio_blk_t_out : UInt64 = 1U.to_uint64()

///|
let virtio_blk_status_ok : UInt64 = 0U.to_uint64()

///|
let virtio_blk_status_unsupp : UInt64 = 2U.to_uint64()

///|
fn Runner::virtio_blk_queue_addr(
  self : Runner,
  lo_index : Int,
  hi_index : Int,
) -> UInt64 {
  self.virtio_blk_state[lo_index] | (self.virtio_blk_state[hi_index] << 32)
}

///|
fn Runner::virtio_blk_capacity(self : Runner) -> UInt64 {
  // Linux reads capacity from the device config area in 512-byte sectors. When
  // no disk is loaded, keep a small deterministic fallback for unit tests.
  let disk_sectors = self.virtio_blk_disk.length() / 512
  if disk_sectors > 0 {
    disk_sectors.reinterpret_as_uint().to_uint64()
  } else {
    virtio_blk_capacity_sectors
  }
}

///|
fn Runner::virtio_blk_write_status(
  self : Runner,
  addr : UInt64,
  status : UInt64,
) -> Unit {
  if self.bus.contains_range(addr, 1) {
    self.bus.store_u8(addr, status)
  }
}

///|
fn Runner::virtio_blk_invalidate_read_cache(self : Runner) -> Unit {
  self.virtio_blk_read_cache_base = virtio_blk_read_cache_invalid_base
  self.virtio_blk_read_cache_bytes = Bytes::from_array([])
}

///|
fn Runner::virtio_blk_fill_read_cache(
  self : Runner,
  disk_byte_offset : UInt64,
  min_len : Int,
) -> Unit {
  let cache_len = if min_len > virtio_blk_read_ahead_bytes {
    min_len
  } else {
    virtio_blk_read_ahead_bytes
  }
  let disk_offset = disk_byte_offset.reinterpret_as_int64().to_int()
  let cache : Array[Byte] = []
  for offset in 0..<cache_len {
    let disk_index = disk_offset + offset
    if disk_index >= 0 && disk_index < self.virtio_blk_disk.length() {
      cache.push(self.virtio_blk_disk[disk_index])
    } else {
      cache.push(0U.to_byte())
    }
  }
  self.virtio_blk_read_cache_base = disk_byte_offset
  self.virtio_blk_read_cache_bytes = Bytes::from_array(cache)
}

///|
fn Runner::virtio_blk_cached_read_offset(
  self : Runner,
  disk_byte_offset : UInt64,
  len : Int,
) -> Int? {
  if self.virtio_blk_read_cache_base == virtio_blk_read_cache_invalid_base {
    return None
  }
  if disk_byte_offset < self.virtio_blk_read_cache_base {
    return None
  }
  let offset = (disk_byte_offset - self.virtio_blk_read_cache_base)
    .reinterpret_as_int64()
    .to_int()
  if offset < 0 || offset + len > self.virtio_blk_read_cache_bytes.length() {
    None
  } else {
    Some(offset)
  }
}

///|
fn Runner::virtio_blk_copy_sector_to_guest(
  self : Runner,
  disk_byte_offset : UInt64,
  guest_addr : UInt64,
  len : Int,
) -> Int {
  // Reads past the end of the backing image are zero-filled. That keeps the
  // device behavior deterministic while the rootfs fixture size changes.
  match self.virtio_blk_cached_read_offset(disk_byte_offset, len) {
    Some(cache_offset) => {
      self.virtio_blk_read_cache_hits += 1U.to_uint64()
      self.bus.write_bytes_from(
        guest_addr,
        self.virtio_blk_read_cache_bytes,
        cache_offset,
        len,
      )
    }
    None => {
      self.virtio_blk_read_cache_misses += 1U.to_uint64()
      self.virtio_blk_fill_read_cache(disk_byte_offset, len)
      self.bus.write_bytes_from(
        guest_addr,
        self.virtio_blk_read_cache_bytes,
        0,
        len,
      )
    }
  }
}

///|
fn Runner::virtio_blk_copy_guest_to_sector(
  self : Runner,
  guest_addr : UInt64,
  disk_byte_offset : UInt64,
  len : Int,
) -> Int {
  // Writes mutate the backing array in place. This path is hot for ext4 and
  // apk install probes, so avoid rebuilding the whole disk image per request.
  let disk_offset = disk_byte_offset.reinterpret_as_int64().to_int()
  let copied = self.bus.copy_bytes_to_array(
    guest_addr,
    self.virtio_blk_disk,
    disk_offset,
    len,
  )
  if copied > 0 {
    self.virtio_blk_invalidate_read_cache()
  }
  copied
}

///|
fn virtio_blk_desc_addr(desc_base : UInt64, index : Int) -> UInt64 {
  desc_base + (index * 16).reinterpret_as_uint().to_uint64()
}

///|
fn virtio_blk_desc_has_next(flags : UInt64) -> Bool {
  (flags & virtq_desc_f_next) != 0U.to_uint64()
}

///|
fn virtio_blk_desc_is_write(flags : UInt64) -> Bool {
  (flags & virtq_desc_f_write) != 0U.to_uint64()
}

///|
fn Runner::virtio_blk_record_completed_request(
  self : Runner,
  request_type : UInt64,
  copied : Int,
) -> Unit {
  // These counters are diagnostic, not guest-visible device state. They let
  // Linux probes distinguish block-I/O progress from CPU-side dynamic loader or
  // relocation work without adding another long trace facility.
  let byte_count = copied.reinterpret_as_uint().to_uint64()
  if request_type == virtio_blk_t_in {
    self.virtio_blk_read_requests += 1U.to_uint64()
    self.virtio_blk_read_bytes += byte_count
  } else if request_type == virtio_blk_t_out {
    self.virtio_blk_write_requests += 1U.to_uint64()
    self.virtio_blk_write_bytes += byte_count
  }
}

///|
fn Runner::virtio_blk_finish_used(
  self : Runner,
  used_base : UInt64,
  queue_num : Int,
  head : UInt64,
  written_len : UInt64,
) -> Unit {
  // A completed virtqueue request has three guest-visible effects: used-ring
  // element, used index advance, and interrupt-status bit. PLIC reflection is
  // handled by the platform layer after the status bit becomes visible.
  if queue_num <= 0 || !self.bus.contains_range(used_base, 4) {
    return
  }
  let used_idx = self.bus.load_u16(used_base + 2U.to_uint64())
  let slot = (used_idx % queue_num.reinterpret_as_uint().to_uint64()).to_int()
  let elem_addr = used_base +
    4U.to_uint64() +
    (slot * 8).reinterpret_as_uint().to_uint64()
  if self.bus.contains_range(elem_addr, 8) {
    self.bus.store_u32(elem_addr, head)
    self.bus.store_u32(elem_addr + 4U.to_uint64(), written_len)
    self.bus.store_u16(
      used_base + 2U.to_uint64(),
      (used_idx + 1U.to_uint64()) & 0xffffU.to_uint64(),
    )
    self.virtio_blk_state[virtio_blk_idx_interrupt_status] = self.virtio_blk_state[virtio_blk_idx_interrupt_status] |
      1U.to_uint64()
  }
}

///|
fn Runner::virtio_blk_process_chain(
  self : Runner,
  desc_base : UInt64,
  used_base : UInt64,
  queue_num : Int,
  head : Int,
) -> Unit {
  // Supported chain shape:
  //   request header -> one or more data descriptors -> writable status byte
  // This is enough for Linux virtio-blk on the Alpine rootfs path without
  // implementing unrelated device features.
  let head_addr = virtio_blk_desc_addr(desc_base, head)
  if !self.bus.contains_range(head_addr, 16) {
    return
  }
  let header_addr = self.bus.load_u64(head_addr)
  let header_len = self.bus.load_u32(head_addr + 8U.to_uint64()).to_int()
  let header_flags = self.bus.load_u16(head_addr + 12U.to_uint64())
  let data_index = self.bus.load_u16(head_addr + 14U.to_uint64()).to_int()
  if header_len < 16 ||
    !virtio_blk_desc_has_next(header_flags) ||
    !self.bus.contains_range(header_addr, 16) {
    return
  }
  let request_type = self.bus.load_u32(header_addr)
  let sector = self.bus.load_u64(header_addr + 8U.to_uint64())
  let mut current = data_index
  let mut copied = 0
  let mut disk_offset = sector * 512U.to_uint64()
  let mut walked = 0
  // Walk the descriptor chain defensively. Linux normally supplies a short
  // header/data/status chain, but malformed chains from tests should not escape
  // the queue or loop forever.
  while walked < queue_num {
    if current < 0 || current >= queue_num {
      return
    }
    let desc_addr = virtio_blk_desc_addr(desc_base, current)
    if !self.bus.contains_range(desc_addr, 16) {
      return
    }
    let guest_addr = self.bus.load_u64(desc_addr)
    let len = self.bus.load_u32(desc_addr + 8U.to_uint64()).to_int()
    let flags = self.bus.load_u16(desc_addr + 12U.to_uint64())
    let has_next = virtio_blk_desc_has_next(flags)
    let is_write = virtio_blk_desc_is_write(flags)
    if !has_next {
      // The final descriptor is the status byte. Linux treats the request as
      // complete only after this byte and the used ring are updated.
      if !is_write {
        return
      }
      let status = if request_type == virtio_blk_t_in ||
        request_type == virtio_blk_t_out {
        virtio_blk_status_ok
      } else {
        virtio_blk_status_unsupp
      }
      if status == virtio_blk_status_ok {
        self.virtio_blk_record_completed_request(request_type, copied)
      }
      self.virtio_blk_write_status(guest_addr, status)
      self.virtio_blk_finish_used(
        used_base,
        queue_num,
        head.reinterpret_as_uint().to_uint64(),
        (copied + 1).reinterpret_as_uint().to_uint64(),
      )
      return
    }
    if request_type == virtio_blk_t_in && !is_write {
      return
    }
    if request_type == virtio_blk_t_out && is_write {
      return
    }
    if request_type == virtio_blk_t_in {
      let chunk = self.virtio_blk_copy_sector_to_guest(
        disk_offset, guest_addr, len,
      )
      copied += chunk
      disk_offset = disk_offset + chunk.reinterpret_as_uint().to_uint64()
    } else if request_type == virtio_blk_t_out {
      let chunk = self.virtio_blk_copy_guest_to_sector(
        guest_addr, disk_offset, len,
      )
      copied += chunk
      disk_offset = disk_offset + chunk.reinterpret_as_uint().to_uint64()
    }
    current = self.bus.load_u16(desc_addr + 14U.to_uint64()).to_int()
    walked += 1
  }
}

///|
fn Runner::virtio_blk_process_available(self : Runner) -> Unit {
  // Consume every new descriptor head the driver published since last notify.
  // `last_avail` is device-private state, mirroring a small virtqueue device.
  let queue_num = self.virtio_blk_state[virtio_blk_idx_queue_num].to_int()
  if queue_num <= 0 ||
    queue_num > virtio_blk_queue_max.to_int() ||
    self.virtio_blk_state[virtio_blk_idx_queue_ready] == 0U.to_uint64() {
    return
  }
  let desc_base = self.virtio_blk_queue_addr(
    virtio_blk_idx_queue_desc_lo, virtio_blk_idx_queue_desc_hi,
  )
  let avail_base = self.virtio_blk_queue_addr(
    virtio_blk_idx_queue_driver_lo, virtio_blk_idx_queue_driver_hi,
  )
  let used_base = self.virtio_blk_queue_addr(
    virtio_blk_idx_queue_device_lo, virtio_blk_idx_queue_device_hi,
  )
  if !self.bus.contains_range(avail_base, 4) ||
    !self.bus.contains_range(used_base, 4) {
    return
  }
  let avail_idx = self.bus.load_u16(avail_base + 2U.to_uint64())
  let mut last = self.virtio_blk_state[virtio_blk_idx_last_avail] &
    0xffffU.to_uint64()
  let mut processed = 0
  while last != avail_idx && processed < queue_num {
    let slot = (last % queue_num.reinterpret_as_uint().to_uint64()).to_int()
    let ring_addr = avail_base +
      4U.to_uint64() +
      (slot * 2).reinterpret_as_uint().to_uint64()
    if !self.bus.contains_range(ring_addr, 2) {
      return
    }
    let head = self.bus.load_u16(ring_addr).to_int()
    if head >= 0 && head < queue_num {
      self.virtio_blk_process_chain(desc_base, used_base, queue_num, head)
    }
    last = (last + 1U.to_uint64()) & 0xffffU.to_uint64()
    processed += 1
  }
  self.virtio_blk_state[virtio_blk_idx_last_avail] = last
}

///|
fn Runner::virtio_blk_read_u32(self : Runner, off : UInt64) -> UInt64 {
  match off {
    0x000 => virtio_mmio_magic
    0x004 => virtio_mmio_version
    0x008 => virtio_blk_device_id
    0x00c => virtio_vendor_riscv_mbt
    0x010 =>
      if self.virtio_blk_state[virtio_blk_idx_device_features_sel] ==
        virtio_feature_version_1_page {
        virtio_feature_version_1_mask
      } else {
        0U.to_uint64()
      }
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
    0x100 => self.virtio_blk_capacity() & 0xffffffffU.to_uint64()
    0x104 => self.virtio_blk_capacity() >> 32
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
    0x050 =>
      if (value32 & 0xffffU.to_uint64()) == 0U.to_uint64() {
        // QueueNotify for queue 0 is where the device consumes split virtqueue
        // descriptors and raises its PLIC interrupt via the platform layer.
        self.virtio_blk_process_available()
      }
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
