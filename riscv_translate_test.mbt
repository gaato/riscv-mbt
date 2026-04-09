///|
let test_pte_v : UInt64 = 0x1U.to_uint64()
let test_pte_r : UInt64 = 0x2U.to_uint64()
let test_pte_w : UInt64 = 0x4U.to_uint64()
let test_pte_x : UInt64 = 0x8U.to_uint64()
let test_pte_u : UInt64 = 0x10U.to_uint64()
let test_pte_a : UInt64 = 0x40U.to_uint64()
let test_pte_d : UInt64 = 0x80U.to_uint64()

///|
/// Build a satp value for Sv39 with the given root page table physical page number.
fn test_sv39_satp(root_ppn : UInt64) -> UInt64 {
  (8U.to_uint64() << 60) | root_ppn
}

///|
/// Build a leaf PTE with given PPN and permission/flag bits.
fn test_make_pte(ppn : UInt64, flags : UInt64) -> UInt64 {
  (ppn << 10) | flags
}

///|
/// Set up a simple identity-mapped 4KB page in the bus:
/// - Root page table at physical page 1 (0x1000)
/// - Level-2 entry points to level-1 table at page 2 (0x2000)
/// - Level-1 entry points to level-0 table at page 3 (0x3000)
/// - Level-0 entry is a leaf mapping VA page 0 → PA page 4 (0x4000)
fn test_setup_identity_map(
  bus : Bus,
  leaf_flags : UInt64,
) -> UInt64 {
  let root_ppn = 1U.to_uint64()
  let l1_ppn = 2U.to_uint64()
  let l0_ppn = 3U.to_uint64()
  let target_ppn = 4U.to_uint64()
  // Level-2 (root) table at 0x1000: entry 0 → level-1 table
  let pte_l2 = test_make_pte(l1_ppn, test_pte_v)
  bus.store_u64(root_ppn * 4096U.to_uint64(), pte_l2)
  // Level-1 table at 0x2000: entry 0 → level-0 table
  let pte_l1 = test_make_pte(l0_ppn, test_pte_v)
  bus.store_u64(l1_ppn * 4096U.to_uint64(), pte_l1)
  // Level-0 table at 0x3000: entry 0 → leaf at target_ppn
  let pte_l0 = test_make_pte(target_ppn, leaf_flags)
  bus.store_u64(l0_ppn * 4096U.to_uint64(), pte_l0)
  test_sv39_satp(root_ppn)
}

///|
test "sv39 translate succeeds for identity-mapped 4KB page" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a | test_pte_d)
  let vaddr = 0x123U.to_uint64() // offset within page 0
  match sv39_translate(bus, satp, vaddr, Load, Supervisor, false, false) {
    TranslatedAddr(pa) => assert_eq(pa, 4U.to_uint64() * 4096U.to_uint64() + 0x123U.to_uint64())
    TranslateFault(_) => fail("expected successful translation")
  }
}

///|
test "sv39 translate faults on invalid PTE (V=0)" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let root_ppn = 1U.to_uint64()
  let satp = test_sv39_satp(root_ppn)
  // Root entry has V=0
  bus.store_u64(root_ppn * 4096U.to_uint64(), 0U.to_uint64())
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        LoadPageFault => ()
        _ => fail("expected LoadPageFault")
      }
    TranslatedAddr(_) => fail("expected page fault")
  }
}

///|
test "sv39 translate faults on reserved W without R" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let root_ppn = 1U.to_uint64()
  let satp = test_sv39_satp(root_ppn)
  // PTE with W=1, R=0 is reserved
  let bad_pte = test_make_pte(0U.to_uint64(), test_pte_v | test_pte_w)
  bus.store_u64(root_ppn * 4096U.to_uint64(), bad_pte)
  match sv39_translate(bus, satp, 0U.to_uint64(), Store, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        StorePageFault => ()
        _ => fail("expected StorePageFault")
      }
    TranslatedAddr(_) => fail("expected page fault for reserved W+!R")
  }
}

///|
test "sv39 translate faults when non-leaf at level 0" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let root_ppn = 1U.to_uint64()
  let l1_ppn = 2U.to_uint64()
  let l0_ppn = 3U.to_uint64()
  let satp = test_sv39_satp(root_ppn)
  // Level-2 → level-1 (non-leaf, V only)
  bus.store_u64(root_ppn * 4096U.to_uint64(), test_make_pte(l1_ppn, test_pte_v))
  // Level-1 → level-0 (non-leaf, V only)
  bus.store_u64(l1_ppn * 4096U.to_uint64(), test_make_pte(l0_ppn, test_pte_v))
  // Level-0: also non-leaf (V only, no R/X) — should fault
  bus.store_u64(l0_ppn * 4096U.to_uint64(), test_make_pte(5U.to_uint64(), test_pte_v))
  match sv39_translate(bus, satp, 0U.to_uint64(), Fetch, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        InstructionPageFault => ()
        _ => fail("expected InstructionPageFault")
      }
    TranslatedAddr(_) => fail("expected fault for non-leaf at level 0")
  }
}

///|
test "sv39 translate succeeds for 2MB superpage" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let root_ppn = 1U.to_uint64()
  let l1_ppn = 2U.to_uint64()
  // Superpage target: PPN with lower 9 bits (PPN[0]) zero
  // Physical page at PPN 0x200 (aligned to 2MB = 512 pages)
  let super_ppn = 0x200U.to_uint64()
  let satp = test_sv39_satp(root_ppn)
  // Level-2 → level-1
  bus.store_u64(root_ppn * 4096U.to_uint64(), test_make_pte(l1_ppn, test_pte_v))
  // Level-1: leaf (superpage), PPN[0]=0 for alignment
  let pte_leaf = test_make_pte(super_ppn, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a | test_pte_d)
  bus.store_u64(l1_ppn * 4096U.to_uint64(), pte_leaf)
  // VA: VPN[2]=0, VPN[1]=0, VPN[0]=5, offset=0x42
  let vaddr = (5U.to_uint64() << 12) | 0x42U.to_uint64()
  match sv39_translate(bus, satp, vaddr, Load, Supervisor, false, false) {
    TranslatedAddr(pa) => {
      // PA = (super_ppn's upper bits) | VPN[0] as PPN[0] | offset
      // super_ppn = 0x200 → physical base = 0x200 * 0x1000 = 0x200000
      // VPN[0] = 5, so PPN[0] gets replaced with 5
      // PA = (0x200 & ~0x1FF) << 12 | (5 << 12) | 0x42
      //    = 0x200 << 12 | 5 << 12 | 0x42
      //    = 0x200000 | 0x5000 | 0x42 = 0x205042
      assert_eq(pa, 0x205042U.to_uint64())
    }
    TranslateFault(_) => fail("expected successful superpage translation")
  }
}

///|
test "sv39 translate faults for misaligned superpage" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let root_ppn = 1U.to_uint64()
  let l1_ppn = 2U.to_uint64()
  // Misaligned: PPN[0] != 0 for a level-1 superpage
  let misaligned_ppn = 0x201U.to_uint64()
  let satp = test_sv39_satp(root_ppn)
  bus.store_u64(root_ppn * 4096U.to_uint64(), test_make_pte(l1_ppn, test_pte_v))
  let pte_leaf = test_make_pte(misaligned_ppn, test_pte_v | test_pte_r | test_pte_x | test_pte_a | test_pte_d)
  bus.store_u64(l1_ppn * 4096U.to_uint64(), pte_leaf)
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        LoadPageFault => ()
        _ => fail("expected LoadPageFault for misaligned superpage")
      }
    TranslatedAddr(_) => fail("expected page fault for misaligned superpage")
  }
}

///|
test "sv39 translate faults when U-page accessed from S-mode without SUM" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_u | test_pte_a | test_pte_d)
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        LoadPageFault => ()
        _ => fail("expected LoadPageFault for U-page from S-mode")
      }
    TranslatedAddr(_) => fail("expected page fault for U-page access from S-mode without SUM")
  }
}

///|
test "sv39 translate succeeds for U-page from S-mode with SUM" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_u | test_pte_a | test_pte_d)
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, true, false) {
    TranslatedAddr(_) => ()
    TranslateFault(_) => fail("expected success with SUM=1")
  }
}

///|
test "sv39 translate faults when S-page accessed from U-mode" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  // No test_pte_u → supervisor page
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a | test_pte_d)
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, User, false, false) {
    TranslateFault(cause) =>
      match cause {
        LoadPageFault => ()
        _ => fail("expected LoadPageFault")
      }
    TranslatedAddr(_) => fail("expected page fault for S-page accessed from U-mode")
  }
}

///|
test "sv39 translate faults when A bit is clear" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  // No test_pte_a
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_d)
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        LoadPageFault => ()
        _ => fail("expected LoadPageFault for A=0")
      }
    TranslatedAddr(_) => fail("expected page fault when A bit is clear")
  }
}

///|
test "sv39 translate faults on store when D bit is clear" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  // Has A but not D
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a)
  match sv39_translate(bus, satp, 0U.to_uint64(), Store, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        StorePageFault => ()
        _ => fail("expected StorePageFault for D=0")
      }
    TranslatedAddr(_) => fail("expected page fault for store with D=0")
  }
}

///|
test "sv39 translate succeeds for load when D bit is clear" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  // Has A but not D — loads should still work
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a)
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, false) {
    TranslatedAddr(_) => ()
    TranslateFault(_) => fail("expected load to succeed even with D=0")
  }
}

///|
test "sv39 translate faults for non-canonical virtual address" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a | test_pte_d)
  // Non-canonical: bit 38 is 0 but upper bits are non-zero
  let bad_va = 1U.to_uint64() << 39
  match sv39_translate(bus, satp, bad_va, Load, Supervisor, false, false) {
    TranslateFault(_) => ()
    TranslatedAddr(_) => fail("expected page fault for non-canonical VA")
  }
}

///|
test "sv39 translate faults when fetch hits read-only page" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  // R only, no X
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_r | test_pte_a | test_pte_d)
  match sv39_translate(bus, satp, 0U.to_uint64(), Fetch, Supervisor, false, false) {
    TranslateFault(cause) =>
      match cause {
        InstructionPageFault => ()
        _ => fail("expected InstructionPageFault")
      }
    TranslatedAddr(_) => fail("expected fault when fetching from non-executable page")
  }
}

///|
test "sv39 translate allows load with MXR on execute-only page" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  // X but not R
  let satp = test_setup_identity_map(bus, test_pte_v | test_pte_x | test_pte_a | test_pte_d)
  // Without MXR: should fault
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, false) {
    TranslateFault(_) => ()
    TranslatedAddr(_) => fail("expected fault without MXR")
  }
  // With MXR: should succeed
  match sv39_translate(bus, satp, 0U.to_uint64(), Load, Supervisor, false, true) {
    TranslatedAddr(_) => ()
    TranslateFault(_) => fail("expected success with MXR=1 on X page")
  }
}

///|
test "sv39 translate 1GB gigapage" {
  let bus = Bus::new(0U.to_uint64(), 0x10000)
  let root_ppn = 1U.to_uint64()
  // Gigapage at level 2: PPN[1] and PPN[0] must be zero
  // PPN = 0x40000 (= 1 << 18, upper bits only)
  let giga_ppn = 0x40000U.to_uint64()
  let satp = test_sv39_satp(root_ppn)
  let pte_leaf = test_make_pte(giga_ppn, test_pte_v | test_pte_r | test_pte_w | test_pte_x | test_pte_a | test_pte_d)
  bus.store_u64(root_ppn * 4096U.to_uint64(), pte_leaf)
  // VA: VPN[2]=0, VPN[1]=3, VPN[0]=7, offset=0xFF
  let vaddr = (3U.to_uint64() << 21) | (7U.to_uint64() << 12) | 0xFFU.to_uint64()
  match sv39_translate(bus, satp, vaddr, Load, Supervisor, false, false) {
    TranslatedAddr(pa) => {
      // PA = giga_ppn base + VPN[1] << 21 + VPN[0] << 12 + offset
      // giga_ppn = 0x40000, base = 0x40000 << 12 = 0x40000000
      // PA = 0x40000000 | (3 << 21) | (7 << 12) | 0xFF
      let expected = (giga_ppn << 12) | (3U.to_uint64() << 21) | (7U.to_uint64() << 12) | 0xFFU.to_uint64()
      assert_eq(pa, expected)
    }
    TranslateFault(_) => fail("expected successful gigapage translation")
  }
}
