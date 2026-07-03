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
  match decode(encode_sfence_vma(1, 2)) {
    SfenceVma(rs1, rs2) => {
      assert_eq(rs1, 1)
      assert_eq(rs2, 2)
    }
    _ => fail("expected sfence.vma")
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

///|
test "decode scalar f instructions" {
  match decode(encode_flw(16, 2, 1)) {
    Flw(rd, rs1, imm) => {
      assert_eq(rd, 1)
      assert_eq(rs1, 2)
      assert_eq(imm, 16)
    }
    _ => fail("expected flw")
  }
  match decode(encode_fsw(20, 3, 4)) {
    Fsw(rs1, rs2, imm) => {
      assert_eq(rs1, 4)
      assert_eq(rs2, 3)
      assert_eq(imm, 20)
    }
    _ => fail("expected fsw")
  }
  match decode(encode_fp_r(0x00U, 6, 5, 0x0U, 4)) {
    FAddS(rd, rs1, rs2, rm) => {
      assert_eq(rd, 4)
      assert_eq(rs1, 5)
      assert_eq(rs2, 6)
      assert_eq(rm, 0U)
    }
    _ => fail("expected fadd.s")
  }
  match decode(encode_fsqrt_s(7, 0x0U, 8)) {
    FSqrtS(rd, rs1, rm) => {
      assert_eq(rd, 8)
      assert_eq(rs1, 7)
      assert_eq(rm, 0U)
    }
    _ => fail("expected fsqrt.s")
  }
  match decode(encode_fmv_x_w(9, 10)) {
    FmvXW(rd, rs1) => {
      assert_eq(rd, 10)
      assert_eq(rs1, 9)
    }
    _ => fail("expected fmv.x.w")
  }
  match decode(encode_fmv_w_x(11, 12)) {
    FmvWX(rd, rs1) => {
      assert_eq(rd, 12)
      assert_eq(rs1, 11)
    }
    _ => fail("expected fmv.w.x")
  }
}

///|
test "decode scalar d instructions" {
  match decode(encode_fld(24, 2, 1)) {
    Fld(rd, rs1, imm) => {
      assert_eq(rd, 1)
      assert_eq(rs1, 2)
      assert_eq(imm, 24)
    }
    _ => fail("expected fld")
  }
  match decode(encode_fsd(32, 3, 4)) {
    Fsd(rs1, rs2, imm) => {
      assert_eq(rs1, 4)
      assert_eq(rs2, 3)
      assert_eq(imm, 32)
    }
    _ => fail("expected fsd")
  }
  match decode(encode_fp_r(0x01U, 6, 5, 0x0U, 4)) {
    FAddD(rd, rs1, rs2, rm) => {
      assert_eq(rd, 4)
      assert_eq(rs1, 5)
      assert_eq(rs2, 6)
      assert_eq(rm, 0U)
    }
    _ => fail("expected fadd.d")
  }
  match decode(encode_fsqrt_d(7, 0x0U, 8)) {
    FSqrtD(rd, rs1, rm) => {
      assert_eq(rd, 8)
      assert_eq(rs1, 7)
      assert_eq(rm, 0U)
    }
    _ => fail("expected fsqrt.d")
  }
  match decode(encode_fmv_x_d(9, 10)) {
    FmvXD(rd, rs1) => {
      assert_eq(rd, 10)
      assert_eq(rs1, 9)
    }
    _ => fail("expected fmv.x.d")
  }
  match decode(encode_fmv_d_x(11, 12)) {
    FmvDX(rd, rs1) => {
      assert_eq(rd, 12)
      assert_eq(rs1, 11)
    }
    _ => fail("expected fmv.d.x")
  }
  match decode(encode_fcvt_s_d(13, 0x0U, 14)) {
    FCvtSD(rd, rs1, rm) => {
      assert_eq(rd, 14)
      assert_eq(rs1, 13)
      assert_eq(rm, 0U)
    }
    _ => fail("expected fcvt.s.d")
  }
  match decode(encode_fcvt_d_s(15, 0x0U, 16)) {
    FCvtDS(rd, rs1, rm) => {
      assert_eq(rd, 16)
      assert_eq(rs1, 15)
      assert_eq(rm, 0U)
    }
    _ => fail("expected fcvt.d.s")
  }
}

///|
test "decode vsetvl family" {
  match decode(encode_vsetvli(1, 2, 0x10U)) {
    Vsetvli(rd, rs1, vtypei) => {
      assert_eq(rd, 1)
      assert_eq(rs1, 2)
      assert_eq(vtypei, 0x10U)
    }
    _ => fail("expected vsetvli")
  }
  match decode(encode_vsetivli(3, 4U, 0x40U)) {
    Vsetivli(rd, avl, vtypei) => {
      assert_eq(rd, 3)
      assert_eq(avl, 4U)
      assert_eq(vtypei, 0x40U)
    }
    _ => fail("expected vsetivli")
  }
  match decode(encode_vsetvl(5, 6, 7)) {
    Vsetvl(rd, rs1, rs2) => {
      assert_eq(rd, 5)
      assert_eq(rs1, 6)
      assert_eq(rs2, 7)
    }
    _ => fail("expected vsetvl")
  }
}

///|
test "decode first vector memory slice" {
  match decode(encode_vle8(1, 2, true)) {
    Vle8V(vd, rs1) => {
      assert_eq(vd, 1)
      assert_eq(rs1, 2)
    }
    _ => fail("expected vle8.v")
  }
  match decode(encode_vle16(3, 4, true)) {
    Vle16V(vd, rs1) => {
      assert_eq(vd, 3)
      assert_eq(rs1, 4)
    }
    _ => fail("expected vle16.v")
  }
  match decode(encode_vle32(5, 6, true)) {
    Vle32V(vd, rs1) => {
      assert_eq(vd, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected vle32.v")
  }
  match decode(encode_vle64(7, 8, true)) {
    Vle64V(vd, rs1) => {
      assert_eq(vd, 7)
      assert_eq(rs1, 8)
    }
    _ => fail("expected vle64.v")
  }
  match decode(encode_vse8(9, 10, true)) {
    Vse8V(vs3, rs1) => {
      assert_eq(vs3, 9)
      assert_eq(rs1, 10)
    }
    _ => fail("expected vse8.v")
  }
  match decode(encode_vse16(11, 12, true)) {
    Vse16V(vs3, rs1) => {
      assert_eq(vs3, 11)
      assert_eq(rs1, 12)
    }
    _ => fail("expected vse16.v")
  }
  match decode(encode_vse32(13, 14, true)) {
    Vse32V(vs3, rs1) => {
      assert_eq(vs3, 13)
      assert_eq(rs1, 14)
    }
    _ => fail("expected vse32.v")
  }
  match decode(encode_vse64(15, 16, true)) {
    Vse64V(vs3, rs1) => {
      assert_eq(vs3, 15)
      assert_eq(rs1, 16)
    }
    _ => fail("expected vse64.v")
  }
}

///|
test "decode first vector arithmetic slice" {
  match decode(encode_vmv_v_i(1, -1)) {
    VmvVI(vd, imm) => {
      assert_eq(vd, 1)
      assert_eq(imm, -1)
    }
    _ => fail("expected vmv.v.i")
  }
  match decode(encode_vmv_v_x(2, 3)) {
    VmvVX(vd, rs1) => {
      assert_eq(vd, 2)
      assert_eq(rs1, 3)
    }
    _ => fail("expected vmv.v.x")
  }
  match decode(encode_vmv_x_s(4, 5)) {
    VmvXS(rd, vs2) => {
      assert_eq(rd, 4)
      assert_eq(vs2, 5)
    }
    _ => fail("expected vmv.x.s")
  }
  match decode(encode_vadd_vv(6, 7, 8, true)) {
    VaddVv(vd, vs2, vs1) => {
      assert_eq(vd, 6)
      assert_eq(vs2, 7)
      assert_eq(vs1, 8)
    }
    _ => fail("expected vadd.vv")
  }
  match decode(encode_vadd_vx(9, 10, 11, true)) {
    VaddVx(vd, vs2, rs1) => {
      assert_eq(vd, 9)
      assert_eq(vs2, 10)
      assert_eq(rs1, 11)
    }
    _ => fail("expected vadd.vx")
  }
  match decode(encode_vadd_vi(12, 13, -2, true)) {
    VaddVi(vd, vs2, imm) => {
      assert_eq(vd, 12)
      assert_eq(vs2, 13)
      assert_eq(imm, -2)
    }
    _ => fail("expected vadd.vi")
  }
  match decode(encode_vadd_vv(1, 2, 3, false)) {
    VaddVv(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected masked vadd.vv")
  }
}
