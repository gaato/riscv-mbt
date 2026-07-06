// White-box compressed-decode regressions for architectural HINT code points.
// Public compressed tests cover execution; this file pins the private
// decompression shape used by traces, profile gates, and instruction caches.

///|
fn wb_encode_c_slli(rd : Int, shamt : Int) -> UInt {
  (0x0002 | (((shamt >> 5) & 0x1) << 12) | (rd << 7) | ((shamt & 0x1f) << 2)).reinterpret_as_uint()
}

///|
fn wb_encode_c_shift_imm(funct2 : Int, rd : Int, imm : Int) -> UInt {
  (0x8001 |
  ((funct2 & 0x3) << 10) |
  (((imm >> 5) & 0x1) << 12) |
  (((rd - 8) & 0x7) << 7) |
  ((imm & 0x1f) << 2)).reinterpret_as_uint()
}

///|
fn wb_encode_c_srli(rd : Int, shamt : Int) -> UInt {
  wb_encode_c_shift_imm(0x0, rd, shamt)
}

///|
fn wb_encode_c_srai(rd : Int, shamt : Int) -> UInt {
  wb_encode_c_shift_imm(0x1, rd, shamt)
}

///|
fn wb_expect_decode_nop(raw : UInt) -> Unit raise {
  match decode_compressed(raw, XLEN_64) {
    Addi(rd, rs1, imm) => {
      assert_eq(rd, 0)
      assert_eq(rs1, 0)
      assert_eq(imm, 0)
    }
    _ => fail("expected compressed hint to decode as canonical nop")
  }
}

///|
test "rv64c compressed zero-shamt shifts decode as canonical hints" {
  // The spec marks the zero-shift encodings as HINTs. Decode them to the
  // emulator's canonical NOP rather than to ordinary zero-distance shifts, so
  // decode traces and future profile gates preserve the architectural class.
  for rd in 8..<=15 {
    wb_expect_decode_nop(wb_encode_c_srli(rd, 0))
    wb_expect_decode_nop(wb_encode_c_srai(rd, 0))
  }
  for rd in 0..<=31 {
    wb_expect_decode_nop(wb_encode_c_slli(rd, 0))
  }

  match decode_compressed(wb_encode_c_srli(8, 1), XLEN_64) {
    Srli(rd, rs1, shamt) => {
      assert_eq(rd, 8)
      assert_eq(rs1, 8)
      assert_eq(shamt, 1)
    }
    _ => fail("expected nonzero c.srli to decode as srli")
  }
  match decode_compressed(wb_encode_c_srai(9, 1), XLEN_64) {
    Srai(rd, rs1, shamt) => {
      assert_eq(rd, 9)
      assert_eq(rs1, 9)
      assert_eq(shamt, 1)
    }
    _ => fail("expected nonzero c.srai to decode as srai")
  }
  match decode_compressed(wb_encode_c_slli(10, 1), XLEN_64) {
    Slli(rd, rs1, shamt) => {
      assert_eq(rd, 10)
      assert_eq(rs1, 10)
      assert_eq(shamt, 1)
    }
    _ => fail("expected nonzero c.slli to decode as slli")
  }
}
