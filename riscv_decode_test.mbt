///|
test "decode addi fields" {
  match decode(encode_i(-4, 2, 0x0U, 1, 0x13U)) {
    Addi(rd, rs1, imm) => {
      assert_eq(rd, 1)
      assert_eq(rs1, 2)
      assert_eq(imm, -4)
    }
    _ => fail("expected addi")
  }
}

///|
test "decode shift immediate fields" {
  match decode(encode_i(3, 4, 0x1U, 5, 0x13U)) {
    Slli(rd, rs1, shamt) => {
      assert_eq(rd, 5)
      assert_eq(rs1, 4)
      assert_eq(shamt, 3)
    }
    _ => fail("expected slli")
  }
}

///|
test "decode bltu fields" {
  match decode(encode_b(-8, 7, 6, 0x6U, 0x63U)) {
    Bltu(rs1, rs2, imm) => {
      assert_eq(rs1, 6)
      assert_eq(rs2, 7)
      assert_eq(imm, -8)
    }
    _ => fail("expected bltu")
  }
}

///|
test "decode mul and div fields" {
  match decode(encode_r(0x01U, 5, 4, 0x0U, 3, 0x33U)) {
    Mul(rd, rs1, rs2) => {
      assert_eq(rd, 3)
      assert_eq(rs1, 4)
      assert_eq(rs2, 5)
    }
    _ => fail("expected mul")
  }
  match decode(encode_r(0x01U, 8, 7, 0x4U, 6, 0x33U)) {
    Div(rd, rs1, rs2) => {
      assert_eq(rd, 6)
      assert_eq(rs1, 7)
      assert_eq(rs2, 8)
    }
    _ => fail("expected div")
  }
}

///|
test "decode fence and fence.i distinctly" {
  match decode(encode_fence()) {
    Fence => ()
    _ => fail("expected fence")
  }
  match decode(encode_fence_i()) {
    FenceI => ()
    _ => fail("expected fence.i")
  }
}

///|
test "decode sret distinctly from mret and ecall" {
  match decode(encode_ecall()) {
    Ecall => ()
    _ => fail("expected ecall")
  }
  match decode(encode_mret()) {
    Mret => ()
    _ => fail("expected mret")
  }
  match decode(encode_sret()) {
    Sret => ()
    _ => fail("expected sret")
  }
}

///|
test "decode rv64-specific word and load instructions" {
  match decode(encode_i(-1, 2, 0x0U, 1, 0x1bU)) {
    Addiw(rd, rs1, imm) => {
      assert_eq(rd, 1)
      assert_eq(rs1, 2)
      assert_eq(imm, -1)
    }
    _ => fail("expected addiw")
  }
  match decode(encode_i(8, 4, 0x6U, 3, 0x03U)) {
    Lwu(rd, rs1, imm) => {
      assert_eq(rd, 3)
      assert_eq(rs1, 4)
      assert_eq(imm, 8)
    }
    _ => fail("expected lwu")
  }
  match decode(encode_r(0x01U, 8, 7, 0x0U, 6, 0x3bU)) {
    Mulw(rd, rs1, rs2) => {
      assert_eq(rd, 6)
      assert_eq(rs1, 7)
      assert_eq(rs2, 8)
    }
    _ => fail("expected mulw")
  }
}
