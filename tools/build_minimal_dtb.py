#!/usr/bin/env python3
"""
Build a minimal FDT (Device Tree Blob) for riscv-mbt.

Describes only the devices the emulator actually implements:
  - memory @ 0x80000000 (128 MB)
  - CPU @ hart 0 with CLINT interrupt controller
  - UART (ns16550a) @ 0x10000000
  - CLINT @ 0x02000000
  - PLIC @ 0x0c000000

Usage:
  python3 tools/build_minimal_dtb.py > _build/minimal.dtb
  python3 tools/build_minimal_dtb.py --moonbit   # print MoonBit byte literal
"""

import struct
import sys


class DTBBuilder:
    FDT_BEGIN_NODE = 1
    FDT_END_NODE   = 2
    FDT_PROP       = 3
    FDT_END        = 9

    def __init__(self):
        self._struct = bytearray()
        self._strings: dict[str, int] = {}
        self._strtab = bytearray()

    def _str_off(self, name: str) -> int:
        if name not in self._strings:
            self._strings[name] = len(self._strtab)
            self._strtab += name.encode() + b'\x00'
        return self._strings[name]

    def begin_node(self, name: str):
        raw = name.encode() + b'\x00'
        pad = (-len(raw)) % 4
        self._struct += struct.pack('>I', self.FDT_BEGIN_NODE) + raw + bytes(pad)

    def end_node(self):
        self._struct += struct.pack('>I', self.FDT_END_NODE)

    def prop(self, name: str, value: bytes):
        off = self._str_off(name)
        pad = (-len(value)) % 4
        self._struct += struct.pack('>III', self.FDT_PROP, len(value), off)
        self._struct += value + bytes(pad)

    def prop_u32(self, name: str, *vals: int):
        self.prop(name, struct.pack(f'>{len(vals)}I', *vals))

    def prop_u64(self, name: str, *vals: int):
        self.prop(name, struct.pack(f'>{len(vals)}Q', *vals))

    def prop_str(self, name: str, val: str):
        self.prop(name, val.encode() + b'\x00')

    def prop_strlist(self, name: str, *vals: str):
        self.prop(name, b''.join(v.encode() + b'\x00' for v in vals))

    def prop_empty(self, name: str):
        self.prop(name, b'')

    def prop_reg2(self, name: str, *pairs):
        """Encode ((addr_hi, addr_lo, size_hi, size_lo), ...) for #addr=2 #size=2."""
        data = b''.join(struct.pack('>IIII', ah, al, sh, sl) for ah, al, sh, sl in pairs)
        self.prop(name, data)

    def build(self) -> bytes:
        self._struct += struct.pack('>I', self.FDT_END)

        HDR_SIZE   = 40
        RSVMAP     = struct.pack('>QQ', 0, 0)   # no reservations
        off_rsvmap = HDR_SIZE
        off_struct = off_rsvmap + len(RSVMAP)
        off_strtab = off_struct + len(self._struct)
        total      = (off_strtab + len(self._strtab) + 3) & ~3

        header = struct.pack('>IIIIIIIIII',
            0xd00dfeed,        # magic
            total,
            off_struct,
            off_strtab,
            off_rsvmap,
            17,                # version
            16,                # last_comp_version
            0,                 # boot_cpuid_phys (hart 0)
            len(self._strtab),
            len(self._struct),
        )
        pad = total - (off_strtab + len(self._strtab))
        return bytes(header) + RSVMAP + bytes(self._struct) + bytes(self._strtab) + bytes(pad)


def build_minimal_dtb(
    ram_base: int   = 0x80000000,
    ram_size: int   = 0x08000000,   # 128 MB
    timebase_freq: int = 0x989680,  # 10 MHz
    uart_base: int  = 0x10000000,
    clint_base: int = 0x02000000,
    plic_base: int  = 0x0c000000,
    bootargs: str   = "",
) -> bytes:
    b = DTBBuilder()

    # Root
    b.begin_node("")
    b.prop_u32("#address-cells", 2)
    b.prop_u32("#size-cells",    2)
    b.prop_str("compatible",     "riscv-virtio")
    b.prop_str("model",          "riscv-virtio,qemu")

    # Memory
    b.begin_node(f"memory@{ram_base:x}")
    b.prop_str("device_type", "memory")
    b.prop_reg2("reg", (0, ram_base, 0, ram_size))
    b.end_node()

    # CPUs
    b.begin_node("cpus")
    b.prop_u32("#address-cells",  1)
    b.prop_u32("#size-cells",     0)
    b.prop_u32("timebase-frequency", timebase_freq)

    b.begin_node("cpu@0")
    b.prop_u32("phandle",    1)
    b.prop_str("device_type","cpu")
    b.prop_u32("reg",        0)
    b.prop_str("status",     "okay")
    b.prop_str("compatible", "riscv")
    b.prop_str("riscv,isa",  "rv64imacsu_zicsr_zifencei")
    b.prop_str("mmu-type",   "riscv,sv39")

    b.begin_node("interrupt-controller")
    b.prop_u32("#interrupt-cells", 1)
    b.prop_empty("interrupt-controller")
    b.prop_str("compatible", "riscv,cpu-intc")
    b.prop_u32("phandle", 2)
    b.end_node()  # interrupt-controller

    b.end_node()  # cpu@0

    b.end_node()  # cpus

    # Chosen
    b.begin_node("chosen")
    stdout = f"/soc/serial@{uart_base:x}"
    b.prop_str("stdout-path", stdout)
    if bootargs:
        b.prop_str("bootargs", bootargs)
    b.end_node()

    # SoC bus
    b.begin_node("soc")
    b.prop_u32("#address-cells", 2)
    b.prop_u32("#size-cells",    2)
    b.prop_str("compatible",     "simple-bus")
    b.prop_empty("ranges")

    # UART
    b.begin_node(f"serial@{uart_base:x}")
    b.prop_u32("interrupts",        0xa)
    b.prop_u32("interrupt-parent",  3)    # PLIC phandle
    b.prop_u32("clock-frequency",   0x384000)
    b.prop_reg2("reg", (0, uart_base, 0, 0x100))
    b.prop_str("compatible", "ns16550a")
    b.end_node()

    # CLINT
    # interrupts-extended: <&cpu-intc MSIP &cpu-intc MTIP>
    #  = phandle=2, cause=3, phandle=2, cause=7
    b.begin_node(f"clint@{clint_base:x}")
    b.prop_u32("interrupts-extended", 2, 3, 2, 7)
    b.prop_reg2("reg", (0, clint_base, 0, 0x10000))
    b.prop_strlist("compatible", "sifive,clint0", "riscv,clint0")
    b.end_node()

    # PLIC
    # interrupts-extended: <&cpu-intc MEIP &cpu-intc SEIP>
    #  = phandle=2, cause=11, phandle=2, cause=9
    b.begin_node(f"plic@{plic_base:x}")
    b.prop_u32("phandle",     3)
    b.prop_u32("riscv,ndev",  0x5f)
    b.prop_reg2("reg", (0, plic_base, 0, 0x600000))
    b.prop_u32("interrupts-extended", 2, 11, 2, 9)
    b.prop_empty("interrupt-controller")
    b.prop_strlist("compatible", "sifive,plic-1.0.0", "riscv,plic0")
    b.prop_u32("#address-cells",   0)
    b.prop_u32("#interrupt-cells", 1)
    b.end_node()

    b.end_node()  # soc
    b.end_node()  # root

    return b.build()


def to_moonbit_bytes(data: bytes) -> str:
    """Format as a MoonBit Bytes literal usable in source."""
    hex_vals = ', '.join(f'b\'\\x{b:02x}\'' for b in data)
    return f'// {len(data)} bytes\n[\n  {hex_vals}\n]'


if __name__ == '__main__':
    dtb = build_minimal_dtb(
        bootargs="earlycon=sbi earlycon console=ttyS0,3686400 root=/dev/ram0 rdinit=/init",
    )
    if '--moonbit' in sys.argv:
        print(to_moonbit_bytes(dtb))
    elif '--verify' in sys.argv:
        # Just print size and first/last bytes for sanity
        print(f"DTB size: {len(dtb)} bytes")
        print(f"Magic: 0x{int.from_bytes(dtb[:4], 'big'):08x}")
        print(f"Total: {int.from_bytes(dtb[4:8], 'big')}")
        print("OK")
    else:
        sys.stdout.buffer.write(dtb)
