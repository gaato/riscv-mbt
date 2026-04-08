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
