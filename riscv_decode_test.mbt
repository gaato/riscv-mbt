// Decode-only regressions. These tests should prove bit encodings and extension
// gating without depending on execution side effects.

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
  match decode(encode_vlm(0, 1)) {
    VlmV(vd, rs1) => {
      assert_eq(vd, 0)
      assert_eq(rs1, 1)
    }
    _ => fail("expected vlm.v")
  }
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
  match decode(encode_vle32(5, 6, false)) {
    Vle32V(vd, rs1) => {
      assert_eq(vd, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected masked vle32.v")
  }
  match decode(encode_vle64(7, 8, true)) {
    Vle64V(vd, rs1) => {
      assert_eq(vd, 7)
      assert_eq(rs1, 8)
    }
    _ => fail("expected vle64.v")
  }
  match decode(encode_vlseg2e32(12, 13, true)) {
    Vlseg2e32V(vd, rs1) => {
      assert_eq(vd, 12)
      assert_eq(rs1, 13)
    }
    _ => fail("expected vlseg2e32.v")
  }
  match decode(encode_vle8ff(2, 3, true)) {
    Vle8ffV(vd, rs1) => {
      assert_eq(vd, 2)
      assert_eq(rs1, 3)
    }
    _ => fail("expected vle8ff.v")
  }
  match decode(encode_vle16ff(4, 5, true)) {
    Vle16ffV(vd, rs1) => {
      assert_eq(vd, 4)
      assert_eq(rs1, 5)
    }
    _ => fail("expected vle16ff.v")
  }
  match decode(encode_vle32ff(6, 7, true)) {
    Vle32ffV(vd, rs1) => {
      assert_eq(vd, 6)
      assert_eq(rs1, 7)
    }
    _ => fail("expected vle32ff.v")
  }
  match decode(encode_vle64ff(8, 9, true)) {
    Vle64ffV(vd, rs1) => {
      assert_eq(vd, 8)
      assert_eq(rs1, 9)
    }
    _ => fail("expected vle64ff.v")
  }
  match decode(encode_vluxei32(23, 24, 25, true)) {
    Vluxei32V(vd, rs1, vs2) => {
      assert_eq(vd, 23)
      assert_eq(rs1, 24)
      assert_eq(vs2, 25)
    }
    _ => fail("expected vluxei32.v")
  }
  match decode(encode_vluxei32(23, 24, 25, false)) {
    Vluxei32V(vd, rs1, vs2) => {
      assert_eq(vd, 23)
      assert_eq(rs1, 24)
      assert_eq(vs2, 25)
    }
    _ => fail("expected masked vluxei32.v")
  }
  match decode(encode_vloxei32(29, 30, 31, true)) {
    Vloxei32V(vd, rs1, vs2) => {
      assert_eq(vd, 29)
      assert_eq(rs1, 30)
      assert_eq(vs2, 31)
    }
    _ => fail("expected vloxei32.v")
  }
  match decode(encode_vlse32(17, 18, 19, true)) {
    Vlse32V(vd, rs1, rs2) => {
      assert_eq(vd, 17)
      assert_eq(rs1, 18)
      assert_eq(rs2, 19)
    }
    _ => fail("expected vlse32.v")
  }
  match decode(encode_vlse32(17, 18, 19, false)) {
    Vlse32V(vd, rs1, rs2) => {
      assert_eq(vd, 17)
      assert_eq(rs1, 18)
      assert_eq(rs2, 19)
    }
    _ => fail("expected masked vlse32.v")
  }
  match decode(encode_vsm(4, 5)) {
    VsmV(vs3, rs1) => {
      assert_eq(vs3, 4)
      assert_eq(rs1, 5)
    }
    _ => fail("expected vsm.v")
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
  match decode(encode_vse32(13, 14, false)) {
    Vse32V(vs3, rs1) => {
      assert_eq(vs3, 13)
      assert_eq(rs1, 14)
    }
    _ => fail("expected masked vse32.v")
  }
  match decode(encode_vse64(15, 16, true)) {
    Vse64V(vs3, rs1) => {
      assert_eq(vs3, 15)
      assert_eq(rs1, 16)
    }
    _ => fail("expected vse64.v")
  }
  match decode(encode_vsseg2e32(18, 19, true)) {
    Vsseg2e32V(vs3, rs1) => {
      assert_eq(vs3, 18)
      assert_eq(rs1, 19)
    }
    _ => fail("expected vsseg2e32.v")
  }
  match decode(encode_vsuxei32(26, 27, 28, true)) {
    Vsuxei32V(vs3, rs1, vs2) => {
      assert_eq(vs3, 26)
      assert_eq(rs1, 27)
      assert_eq(vs2, 28)
    }
    _ => fail("expected vsuxei32.v")
  }
  match decode(encode_vsoxei32(1, 2, 3, true)) {
    Vsoxei32V(vs3, rs1, vs2) => {
      assert_eq(vs3, 1)
      assert_eq(rs1, 2)
      assert_eq(vs2, 3)
    }
    _ => fail("expected vsoxei32.v")
  }
  match decode(encode_vsse32(20, 21, 22, true)) {
    Vsse32V(vs3, rs1, rs2) => {
      assert_eq(vs3, 20)
      assert_eq(rs1, 21)
      assert_eq(rs2, 22)
    }
    _ => fail("expected vsse32.v")
  }
  match decode(encode_vsse32(20, 21, 22, false)) {
    Vsse32V(vs3, rs1, rs2) => {
      assert_eq(vs3, 20)
      assert_eq(rs1, 21)
      assert_eq(rs2, 22)
    }
    _ => fail("expected masked vsse32.v")
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
  match decode(encode_vmv_v_v(6, 7)) {
    VmvVV(vd, vs1) => {
      assert_eq(vd, 6)
      assert_eq(vs1, 7)
    }
    _ => fail("expected vmv.v.v")
  }
  match decode(encode_vop(0x17U, true, 2, 3, 0x0U, 1)) {
    Unknown(_) => ()
    _ => fail("expected unmasked non-vmv vmerge.vvm encoding to be reserved")
  }
  match decode(encode_vmerge_vvm(8, 9, 10)) {
    VmergeVvm(vd, vs2, vs1) => {
      assert_eq(vd, 8)
      assert_eq(vs2, 9)
      assert_eq(vs1, 10)
    }
    _ => fail("expected vmerge.vvm")
  }
  match decode(encode_vmerge_vxm(11, 12, 13)) {
    VmergeVxm(vd, vs2, rs1) => {
      assert_eq(vd, 11)
      assert_eq(vs2, 12)
      assert_eq(rs1, 13)
    }
    _ => fail("expected vmerge.vxm")
  }
  match decode(encode_vmerge_vim(14, 15, -1)) {
    VmergeVim(vd, vs2, imm) => {
      assert_eq(vd, 14)
      assert_eq(vs2, 15)
      assert_eq(imm, -1)
    }
    _ => fail("expected vmerge.vim")
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
  match decode(encode_vsub_vv(14, 15, 16, true)) {
    VsubVv(vd, vs2, vs1) => {
      assert_eq(vd, 14)
      assert_eq(vs2, 15)
      assert_eq(vs1, 16)
    }
    _ => fail("expected vsub.vv")
  }
  match decode(encode_vsub_vx(17, 18, 19, true)) {
    VsubVx(vd, vs2, rs1) => {
      assert_eq(vd, 17)
      assert_eq(vs2, 18)
      assert_eq(rs1, 19)
    }
    _ => fail("expected vsub.vx")
  }
  match decode(encode_vrsub_vx(20, 21, 22, true)) {
    VrsubVx(vd, vs2, rs1) => {
      assert_eq(vd, 20)
      assert_eq(vs2, 21)
      assert_eq(rs1, 22)
    }
    _ => fail("expected vrsub.vx")
  }
  match decode(encode_vrsub_vi(23, 24, -2, false)) {
    VrsubVi(vd, vs2, imm) => {
      assert_eq(vd, 23)
      assert_eq(vs2, 24)
      assert_eq(imm, -2)
    }
    _ => fail("expected masked vrsub.vi")
  }
  match decode(encode_vwaddu_vv(1, 2, 3, true)) {
    VwadduVv(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected vwaddu.vv")
  }
  match decode(encode_vwaddu_vx(4, 5, 6, true)) {
    VwadduVx(vd, vs2, rs1) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected vwaddu.vx")
  }
  match decode(encode_vwadd_vv(7, 8, 9, false)) {
    VwaddVv(vd, vs2, vs1) => {
      assert_eq(vd, 7)
      assert_eq(vs2, 8)
      assert_eq(vs1, 9)
    }
    _ => fail("expected vwadd.vv")
  }
  match decode(encode_vwadd_vx(10, 11, 12, true)) {
    VwaddVx(vd, vs2, rs1) => {
      assert_eq(vd, 10)
      assert_eq(vs2, 11)
      assert_eq(rs1, 12)
    }
    _ => fail("expected vwadd.vx")
  }
  match decode(encode_vwsubu_vv(13, 14, 15, true)) {
    VwsubuVv(vd, vs2, vs1) => {
      assert_eq(vd, 13)
      assert_eq(vs2, 14)
      assert_eq(vs1, 15)
    }
    _ => fail("expected vwsubu.vv")
  }
  match decode(encode_vwsubu_vx(16, 17, 18, false)) {
    VwsubuVx(vd, vs2, rs1) => {
      assert_eq(vd, 16)
      assert_eq(vs2, 17)
      assert_eq(rs1, 18)
    }
    _ => fail("expected vwsubu.vx")
  }
  match decode(encode_vwsub_vv(19, 20, 21, true)) {
    VwsubVv(vd, vs2, vs1) => {
      assert_eq(vd, 19)
      assert_eq(vs2, 20)
      assert_eq(vs1, 21)
    }
    _ => fail("expected vwsub.vv")
  }
  match decode(encode_vwsub_vx(22, 23, 24, false)) {
    VwsubVx(vd, vs2, rs1) => {
      assert_eq(vd, 22)
      assert_eq(vs2, 23)
      assert_eq(rs1, 24)
    }
    _ => fail("expected vwsub.vx")
  }
  match decode(encode_vmul_vv(30, 31, 1, true)) {
    VmulVv(vd, vs2, vs1) => {
      assert_eq(vd, 30)
      assert_eq(vs2, 31)
      assert_eq(vs1, 1)
    }
    _ => fail("expected vmul.vv")
  }
  match decode(encode_vmul_vx(2, 3, 4, false)) {
    VmulVx(vd, vs2, rs1) => {
      assert_eq(vd, 2)
      assert_eq(vs2, 3)
      assert_eq(rs1, 4)
    }
    _ => fail("expected masked vmul.vx")
  }
  match decode(encode_vmulhu_vv(5, 6, 7, true)) {
    VmulhuVv(vd, vs2, vs1) => {
      assert_eq(vd, 5)
      assert_eq(vs2, 6)
      assert_eq(vs1, 7)
    }
    _ => fail("expected vmulhu.vv")
  }
  match decode(encode_vmulhu_vx(8, 9, 10, true)) {
    VmulhuVx(vd, vs2, rs1) => {
      assert_eq(vd, 8)
      assert_eq(vs2, 9)
      assert_eq(rs1, 10)
    }
    _ => fail("expected vmulhu.vx")
  }
  match decode(encode_vmulhsu_vv(11, 12, 13, false)) {
    VmulhsuVv(vd, vs2, vs1) => {
      assert_eq(vd, 11)
      assert_eq(vs2, 12)
      assert_eq(vs1, 13)
    }
    _ => fail("expected masked vmulhsu.vv")
  }
  match decode(encode_vmulhsu_vx(14, 15, 16, false)) {
    VmulhsuVx(vd, vs2, rs1) => {
      assert_eq(vd, 14)
      assert_eq(vs2, 15)
      assert_eq(rs1, 16)
    }
    _ => fail("expected masked vmulhsu.vx")
  }
  match decode(encode_vmulh_vv(17, 18, 19, true)) {
    VmulhVv(vd, vs2, vs1) => {
      assert_eq(vd, 17)
      assert_eq(vs2, 18)
      assert_eq(vs1, 19)
    }
    _ => fail("expected vmulh.vv")
  }
  match decode(encode_vmulh_vx(20, 21, 22, true)) {
    VmulhVx(vd, vs2, rs1) => {
      assert_eq(vd, 20)
      assert_eq(vs2, 21)
      assert_eq(rs1, 22)
    }
    _ => fail("expected vmulh.vx")
  }
  match decode(encode_vdivu_vv(23, 24, 25, true)) {
    VdivuVv(vd, vs2, vs1) => {
      assert_eq(vd, 23)
      assert_eq(vs2, 24)
      assert_eq(vs1, 25)
    }
    _ => fail("expected vdivu.vv")
  }
  match decode(encode_vdivu_vx(26, 27, 28, false)) {
    VdivuVx(vd, vs2, rs1) => {
      assert_eq(vd, 26)
      assert_eq(vs2, 27)
      assert_eq(rs1, 28)
    }
    _ => fail("expected masked vdivu.vx")
  }
  match decode(encode_vdiv_vv(29, 30, 31, true)) {
    VdivVv(vd, vs2, vs1) => {
      assert_eq(vd, 29)
      assert_eq(vs2, 30)
      assert_eq(vs1, 31)
    }
    _ => fail("expected vdiv.vv")
  }
  match decode(encode_vdiv_vx(1, 2, 3, true)) {
    VdivVx(vd, vs2, rs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(rs1, 3)
    }
    _ => fail("expected vdiv.vx")
  }
  match decode(encode_vremu_vv(4, 5, 6, true)) {
    VremuVv(vd, vs2, vs1) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(vs1, 6)
    }
    _ => fail("expected vremu.vv")
  }
  match decode(encode_vremu_vx(7, 8, 9, false)) {
    VremuVx(vd, vs2, rs1) => {
      assert_eq(vd, 7)
      assert_eq(vs2, 8)
      assert_eq(rs1, 9)
    }
    _ => fail("expected masked vremu.vx")
  }
  match decode(encode_vrem_vv(10, 11, 12, true)) {
    VremVv(vd, vs2, vs1) => {
      assert_eq(vd, 10)
      assert_eq(vs2, 11)
      assert_eq(vs1, 12)
    }
    _ => fail("expected vrem.vv")
  }
  match decode(encode_vrem_vx(13, 14, 15, true)) {
    VremVx(vd, vs2, rs1) => {
      assert_eq(vd, 13)
      assert_eq(vs2, 14)
      assert_eq(rs1, 15)
    }
    _ => fail("expected vrem.vx")
  }
  match decode(encode_vminu_vv(18, 19, 20, true)) {
    VminuVv(vd, vs2, vs1) => {
      assert_eq(vd, 18)
      assert_eq(vs2, 19)
      assert_eq(vs1, 20)
    }
    _ => fail("expected vminu.vv")
  }
  match decode(encode_vminu_vx(21, 22, 23, true)) {
    VminuVx(vd, vs2, rs1) => {
      assert_eq(vd, 21)
      assert_eq(vs2, 22)
      assert_eq(rs1, 23)
    }
    _ => fail("expected vminu.vx")
  }
  match decode(encode_vmin_vv(24, 25, 26, true)) {
    VminVv(vd, vs2, vs1) => {
      assert_eq(vd, 24)
      assert_eq(vs2, 25)
      assert_eq(vs1, 26)
    }
    _ => fail("expected vmin.vv")
  }
  match decode(encode_vmin_vx(27, 28, 29, true)) {
    VminVx(vd, vs2, rs1) => {
      assert_eq(vd, 27)
      assert_eq(vs2, 28)
      assert_eq(rs1, 29)
    }
    _ => fail("expected vmin.vx")
  }
  match decode(encode_vmaxu_vv(1, 2, 3, true)) {
    VmaxuVv(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected vmaxu.vv")
  }
  match decode(encode_vmaxu_vx(4, 5, 6, true)) {
    VmaxuVx(vd, vs2, rs1) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected vmaxu.vx")
  }
  match decode(encode_vmax_vv(7, 8, 9, true)) {
    VmaxVv(vd, vs2, vs1) => {
      assert_eq(vd, 7)
      assert_eq(vs2, 8)
      assert_eq(vs1, 9)
    }
    _ => fail("expected vmax.vv")
  }
  match decode(encode_vmax_vx(10, 11, 12, true)) {
    VmaxVx(vd, vs2, rs1) => {
      assert_eq(vd, 10)
      assert_eq(vs2, 11)
      assert_eq(rs1, 12)
    }
    _ => fail("expected vmax.vx")
  }
  match decode(encode_vmseq_vv(13, 14, 15, true)) {
    VmseqVv(vd, vs2, vs1) => {
      assert_eq(vd, 13)
      assert_eq(vs2, 14)
      assert_eq(vs1, 15)
    }
    _ => fail("expected vmseq.vv")
  }
  match decode(encode_vmseq_vx(16, 17, 18, true)) {
    VmseqVx(vd, vs2, rs1) => {
      assert_eq(vd, 16)
      assert_eq(vs2, 17)
      assert_eq(rs1, 18)
    }
    _ => fail("expected vmseq.vx")
  }
  match decode(encode_vmseq_vi(19, 20, -1, true)) {
    VmseqVi(vd, vs2, imm) => {
      assert_eq(vd, 19)
      assert_eq(vs2, 20)
      assert_eq(imm, -1)
    }
    _ => fail("expected vmseq.vi")
  }
  match decode(encode_vmsne_vv(21, 22, 23, true)) {
    VmsneVv(vd, vs2, vs1) => {
      assert_eq(vd, 21)
      assert_eq(vs2, 22)
      assert_eq(vs1, 23)
    }
    _ => fail("expected vmsne.vv")
  }
  match decode(encode_vmsne_vx(24, 25, 26, true)) {
    VmsneVx(vd, vs2, rs1) => {
      assert_eq(vd, 24)
      assert_eq(vs2, 25)
      assert_eq(rs1, 26)
    }
    _ => fail("expected vmsne.vx")
  }
  match decode(encode_vmsne_vi(27, 28, -16, true)) {
    VmsneVi(vd, vs2, imm) => {
      assert_eq(vd, 27)
      assert_eq(vs2, 28)
      assert_eq(imm, -16)
    }
    _ => fail("expected vmsne.vi")
  }
  match decode(encode_vmsltu_vv(1, 2, 3, true)) {
    VmsltuVv(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected vmsltu.vv")
  }
  match decode(encode_vmsltu_vx(4, 5, 6, true)) {
    VmsltuVx(vd, vs2, rs1) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected vmsltu.vx")
  }
  match decode(encode_vmslt_vv(7, 8, 9, true)) {
    VmsltVv(vd, vs2, vs1) => {
      assert_eq(vd, 7)
      assert_eq(vs2, 8)
      assert_eq(vs1, 9)
    }
    _ => fail("expected vmslt.vv")
  }
  match decode(encode_vmslt_vx(10, 11, 12, true)) {
    VmsltVx(vd, vs2, rs1) => {
      assert_eq(vd, 10)
      assert_eq(vs2, 11)
      assert_eq(rs1, 12)
    }
    _ => fail("expected vmslt.vx")
  }
  match decode(encode_vmsleu_vv(13, 14, 15, true)) {
    VmsleuVv(vd, vs2, vs1) => {
      assert_eq(vd, 13)
      assert_eq(vs2, 14)
      assert_eq(vs1, 15)
    }
    _ => fail("expected vmsleu.vv")
  }
  match decode(encode_vmsleu_vx(16, 17, 18, true)) {
    VmsleuVx(vd, vs2, rs1) => {
      assert_eq(vd, 16)
      assert_eq(vs2, 17)
      assert_eq(rs1, 18)
    }
    _ => fail("expected vmsleu.vx")
  }
  match decode(encode_vmsleu_vi(19, 20, 15, true)) {
    VmsleuVi(vd, vs2, imm) => {
      assert_eq(vd, 19)
      assert_eq(vs2, 20)
      assert_eq(imm, 15)
    }
    _ => fail("expected vmsleu.vi")
  }
  match decode(encode_vmsle_vv(21, 22, 23, true)) {
    VmsleVv(vd, vs2, vs1) => {
      assert_eq(vd, 21)
      assert_eq(vs2, 22)
      assert_eq(vs1, 23)
    }
    _ => fail("expected vmsle.vv")
  }
  match decode(encode_vmsle_vx(24, 25, 26, true)) {
    VmsleVx(vd, vs2, rs1) => {
      assert_eq(vd, 24)
      assert_eq(vs2, 25)
      assert_eq(rs1, 26)
    }
    _ => fail("expected vmsle.vx")
  }
  match decode(encode_vmsle_vi(27, 28, -1, true)) {
    VmsleVi(vd, vs2, imm) => {
      assert_eq(vd, 27)
      assert_eq(vs2, 28)
      assert_eq(imm, -1)
    }
    _ => fail("expected vmsle.vi")
  }
  match decode(encode_vmsgtu_vx(1, 2, 3, true)) {
    VmsgtuVx(vd, vs2, rs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(rs1, 3)
    }
    _ => fail("expected vmsgtu.vx")
  }
  match decode(encode_vmsgtu_vi(4, 5, 15, true)) {
    VmsgtuVi(vd, vs2, imm) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(imm, 15)
    }
    _ => fail("expected vmsgtu.vi")
  }
  match decode(encode_vmsgt_vx(6, 7, 8, true)) {
    VmsgtVx(vd, vs2, rs1) => {
      assert_eq(vd, 6)
      assert_eq(vs2, 7)
      assert_eq(rs1, 8)
    }
    _ => fail("expected vmsgt.vx")
  }
  match decode(encode_vmsgt_vi(9, 10, -16, true)) {
    VmsgtVi(vd, vs2, imm) => {
      assert_eq(vd, 9)
      assert_eq(vs2, 10)
      assert_eq(imm, -16)
    }
    _ => fail("expected vmsgt.vi")
  }
  match decode(encode_vmand_mm(11, 12, 13)) {
    VmandMm(vd, vs2, vs1) => {
      assert_eq(vd, 11)
      assert_eq(vs2, 12)
      assert_eq(vs1, 13)
    }
    _ => fail("expected vmand.mm")
  }
  match decode(encode_vmnand_mm(14, 15, 16)) {
    VmnandMm(vd, vs2, vs1) => {
      assert_eq(vd, 14)
      assert_eq(vs2, 15)
      assert_eq(vs1, 16)
    }
    _ => fail("expected vmnand.mm")
  }
  match decode(encode_vmandn_mm(17, 18, 19)) {
    VmandnMm(vd, vs2, vs1) => {
      assert_eq(vd, 17)
      assert_eq(vs2, 18)
      assert_eq(vs1, 19)
    }
    _ => fail("expected vmandn.mm")
  }
  match decode(encode_vmxor_mm(20, 21, 22)) {
    VmxorMm(vd, vs2, vs1) => {
      assert_eq(vd, 20)
      assert_eq(vs2, 21)
      assert_eq(vs1, 22)
    }
    _ => fail("expected vmxor.mm")
  }
  match decode(encode_vmor_mm(23, 24, 25)) {
    VmorMm(vd, vs2, vs1) => {
      assert_eq(vd, 23)
      assert_eq(vs2, 24)
      assert_eq(vs1, 25)
    }
    _ => fail("expected vmor.mm")
  }
  match decode(encode_vmnor_mm(26, 27, 28)) {
    VmnorMm(vd, vs2, vs1) => {
      assert_eq(vd, 26)
      assert_eq(vs2, 27)
      assert_eq(vs1, 28)
    }
    _ => fail("expected vmnor.mm")
  }
  match decode(encode_vmorn_mm(29, 30, 31)) {
    VmornMm(vd, vs2, vs1) => {
      assert_eq(vd, 29)
      assert_eq(vs2, 30)
      assert_eq(vs1, 31)
    }
    _ => fail("expected vmorn.mm")
  }
  match decode(encode_vmxnor_mm(1, 2, 3)) {
    VmxnorMm(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected vmxnor.mm")
  }
  match decode(encode_vop(0x18U, false, 12, 13, 0x2U, 11)) {
    Unknown(_) => ()
    _ => fail("expected masked vmand.mm encoding to remain reserved")
  }
  match decode(encode_vcpop_m(4, 5, true)) {
    VcpopM(rd, vs2) => {
      assert_eq(rd, 4)
      assert_eq(vs2, 5)
    }
    _ => fail("expected vcpop.m")
  }
  match decode(encode_vcpop_m(6, 7, false)) {
    VcpopM(rd, vs2) => {
      assert_eq(rd, 6)
      assert_eq(vs2, 7)
    }
    _ => fail("expected masked vcpop.m")
  }
  match decode(encode_vfirst_m(8, 9, true)) {
    VfirstM(rd, vs2) => {
      assert_eq(rd, 8)
      assert_eq(vs2, 9)
    }
    _ => fail("expected vfirst.m")
  }
  match decode(encode_vfirst_m(10, 11, false)) {
    VfirstM(rd, vs2) => {
      assert_eq(rd, 10)
      assert_eq(vs2, 11)
    }
    _ => fail("expected masked vfirst.m")
  }
  match decode(encode_vmsbf_m(12, 13, true)) {
    VmsbfM(vd, vs2) => {
      assert_eq(vd, 12)
      assert_eq(vs2, 13)
    }
    _ => fail("expected vmsbf.m")
  }
  match decode(encode_vmsof_m(14, 15, false)) {
    VmsofM(vd, vs2) => {
      assert_eq(vd, 14)
      assert_eq(vs2, 15)
    }
    _ => fail("expected masked vmsof.m")
  }
  match decode(encode_vmsif_m(16, 17, true)) {
    VmsifM(vd, vs2) => {
      assert_eq(vd, 16)
      assert_eq(vs2, 17)
    }
    _ => fail("expected vmsif.m")
  }
  match decode(encode_viota_m(18, 19, true)) {
    ViotaM(vd, vs2) => {
      assert_eq(vd, 18)
      assert_eq(vs2, 19)
    }
    _ => fail("expected viota.m")
  }
  match decode(encode_viota_m(20, 21, false)) {
    ViotaM(vd, vs2) => {
      assert_eq(vd, 20)
      assert_eq(vs2, 21)
    }
    _ => fail("expected masked viota.m")
  }
  match decode(encode_vid_v(22, true)) {
    VidV(vd) => assert_eq(vd, 22)
    _ => fail("expected vid.v")
  }
  match decode(encode_vid_v(23, false)) {
    VidV(vd) => assert_eq(vd, 23)
    _ => fail("expected masked vid.v")
  }
  match decode(encode_vop(0x14U, true, 1, 0x11, 0x2U, 24)) {
    Unknown(_) => ()
    _ => fail("expected vid.v with nonzero vs2 field to remain reserved")
  }
  match decode(encode_vcompress_vm(24, 25, 26, true)) {
    VcompressVm(vd, vs2, vs1) => {
      assert_eq(vd, 24)
      assert_eq(vs2, 25)
      assert_eq(vs1, 26)
    }
    _ => fail("expected vcompress.vm")
  }
  match decode(encode_vcompress_vm(24, 25, 26, false)) {
    Unknown(_) => ()
    _ => fail("expected masked vcompress.vm encoding to remain reserved")
  }
  match decode(encode_vrgather_vv(25, 26, 27, true)) {
    VrgatherVv(vd, vs2, vs1) => {
      assert_eq(vd, 25)
      assert_eq(vs2, 26)
      assert_eq(vs1, 27)
    }
    _ => fail("expected vrgather.vv")
  }
  match decode(encode_vrgather_vx(28, 29, 30, false)) {
    VrgatherVx(vd, vs2, rs1) => {
      assert_eq(vd, 28)
      assert_eq(vs2, 29)
      assert_eq(rs1, 30)
    }
    _ => fail("expected masked vrgather.vx")
  }
  match decode(encode_vrgather_vi(1, 2, 31, true)) {
    VrgatherVi(vd, vs2, imm) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(imm, 31)
    }
    _ => fail("expected vrgather.vi")
  }
  match decode(encode_vslideup_vx(3, 4, 5, false)) {
    VslideupVx(vd, vs2, rs1) => {
      assert_eq(vd, 3)
      assert_eq(vs2, 4)
      assert_eq(rs1, 5)
    }
    _ => fail("expected masked vslideup.vx")
  }
  match decode(encode_vslideup_vi(6, 7, 8, true)) {
    VslideupVi(vd, vs2, imm) => {
      assert_eq(vd, 6)
      assert_eq(vs2, 7)
      assert_eq(imm, 8)
    }
    _ => fail("expected vslideup.vi")
  }
  match decode(encode_vslidedown_vx(9, 10, 11, true)) {
    VslidedownVx(vd, vs2, rs1) => {
      assert_eq(vd, 9)
      assert_eq(vs2, 10)
      assert_eq(rs1, 11)
    }
    _ => fail("expected vslidedown.vx")
  }
  match decode(encode_vslidedown_vi(12, 13, 31, false)) {
    VslidedownVi(vd, vs2, imm) => {
      assert_eq(vd, 12)
      assert_eq(vs2, 13)
      assert_eq(imm, 31)
    }
    _ => fail("expected masked vslidedown.vi")
  }
  match decode(encode_vslide1up_vx(14, 15, 16, false)) {
    Vslide1upVx(vd, vs2, rs1) => {
      assert_eq(vd, 14)
      assert_eq(vs2, 15)
      assert_eq(rs1, 16)
    }
    _ => fail("expected masked vslide1up.vx")
  }
  match decode(encode_vslide1down_vx(17, 18, 19, true)) {
    Vslide1downVx(vd, vs2, rs1) => {
      assert_eq(vd, 17)
      assert_eq(vs2, 18)
      assert_eq(rs1, 19)
    }
    _ => fail("expected vslide1down.vx")
  }
  match decode(encode_vmv_nr_r(8, 16, 4, true)) {
    VmvNrR(vd, vs2, nreg) => {
      assert_eq(vd, 8)
      assert_eq(vs2, 16)
      assert_eq(nreg, 4)
    }
    _ => fail("expected vmv4r.v")
  }
  match decode(encode_vmv_nr_r(8, 16, 4, false)) {
    Unknown(_) => ()
    _ => fail("expected masked vmv4r.v encoding to remain reserved")
  }
  match decode(encode_vmv_nr_r(8, 16, 3, true)) {
    Unknown(_) => ()
    _ => fail("expected reserved whole-register move NREG to remain reserved")
  }
  match decode(encode_vsll_vv(13, 14, 15, true)) {
    VsllVv(vd, vs2, vs1) => {
      assert_eq(vd, 13)
      assert_eq(vs2, 14)
      assert_eq(vs1, 15)
    }
    _ => fail("expected vsll.vv")
  }
  match decode(encode_vsll_vx(16, 17, 18, true)) {
    VsllVx(vd, vs2, rs1) => {
      assert_eq(vd, 16)
      assert_eq(vs2, 17)
      assert_eq(rs1, 18)
    }
    _ => fail("expected vsll.vx")
  }
  match decode(encode_vsll_vi(19, 20, 31, true)) {
    VsllVi(vd, vs2, imm) => {
      assert_eq(vd, 19)
      assert_eq(vs2, 20)
      assert_eq(imm, 31)
    }
    _ => fail("expected vsll.vi")
  }
  match decode(encode_vsrl_vv(21, 22, 23, true)) {
    VsrlVv(vd, vs2, vs1) => {
      assert_eq(vd, 21)
      assert_eq(vs2, 22)
      assert_eq(vs1, 23)
    }
    _ => fail("expected vsrl.vv")
  }
  match decode(encode_vsrl_vx(24, 25, 26, true)) {
    VsrlVx(vd, vs2, rs1) => {
      assert_eq(vd, 24)
      assert_eq(vs2, 25)
      assert_eq(rs1, 26)
    }
    _ => fail("expected vsrl.vx")
  }
  match decode(encode_vsrl_vi(27, 28, 31, true)) {
    VsrlVi(vd, vs2, imm) => {
      assert_eq(vd, 27)
      assert_eq(vs2, 28)
      assert_eq(imm, 31)
    }
    _ => fail("expected vsrl.vi")
  }
  match decode(encode_vsra_vv(1, 2, 3, true)) {
    VsraVv(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected vsra.vv")
  }
  match decode(encode_vsra_vx(4, 5, 6, true)) {
    VsraVx(vd, vs2, rs1) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected vsra.vx")
  }
  match decode(encode_vsra_vi(7, 8, 31, true)) {
    VsraVi(vd, vs2, imm) => {
      assert_eq(vd, 7)
      assert_eq(vs2, 8)
      assert_eq(imm, 31)
    }
    _ => fail("expected vsra.vi")
  }
  match decode(encode_vand_vv(20, 21, 22, true)) {
    VandVv(vd, vs2, vs1) => {
      assert_eq(vd, 20)
      assert_eq(vs2, 21)
      assert_eq(vs1, 22)
    }
    _ => fail("expected vand.vv")
  }
  match decode(encode_vand_vx(23, 24, 25, true)) {
    VandVx(vd, vs2, rs1) => {
      assert_eq(vd, 23)
      assert_eq(vs2, 24)
      assert_eq(rs1, 25)
    }
    _ => fail("expected vand.vx")
  }
  match decode(encode_vand_vi(26, 27, -1, true)) {
    VandVi(vd, vs2, imm) => {
      assert_eq(vd, 26)
      assert_eq(vs2, 27)
      assert_eq(imm, -1)
    }
    _ => fail("expected vand.vi")
  }
  match decode(encode_vor_vv(1, 2, 3, true)) {
    VorVv(vd, vs2, vs1) => {
      assert_eq(vd, 1)
      assert_eq(vs2, 2)
      assert_eq(vs1, 3)
    }
    _ => fail("expected vor.vv")
  }
  match decode(encode_vor_vx(4, 5, 6, true)) {
    VorVx(vd, vs2, rs1) => {
      assert_eq(vd, 4)
      assert_eq(vs2, 5)
      assert_eq(rs1, 6)
    }
    _ => fail("expected vor.vx")
  }
  match decode(encode_vor_vi(7, 8, 9, true)) {
    VorVi(vd, vs2, imm) => {
      assert_eq(vd, 7)
      assert_eq(vs2, 8)
      assert_eq(imm, 9)
    }
    _ => fail("expected vor.vi")
  }
  match decode(encode_vxor_vv(9, 10, 11, true)) {
    VxorVv(vd, vs2, vs1) => {
      assert_eq(vd, 9)
      assert_eq(vs2, 10)
      assert_eq(vs1, 11)
    }
    _ => fail("expected vxor.vv")
  }
  match decode(encode_vxor_vx(12, 13, 14, true)) {
    VxorVx(vd, vs2, rs1) => {
      assert_eq(vd, 12)
      assert_eq(vs2, 13)
      assert_eq(rs1, 14)
    }
    _ => fail("expected vxor.vx")
  }
  match decode(encode_vxor_vi(15, 16, -1, true)) {
    VxorVi(vd, vs2, imm) => {
      assert_eq(vd, 15)
      assert_eq(vs2, 16)
      assert_eq(imm, -1)
    }
    _ => fail("expected vxor.vi")
  }
}
