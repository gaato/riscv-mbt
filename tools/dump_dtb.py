#!/usr/bin/env python3
"""Dump a DTB file in human-readable form."""
import struct, sys

def dump_dtb(path):
    data = open(path, 'rb').read()
    FDT_HEADER_SIZE = 40
    magic, totalsize, off_dt_struct, off_dt_strings, off_mem_rsvmap, \
        version, last_comp_version, boot_cpuid_phys, size_dt_strings, \
        size_dt_struct = struct.unpack('>IIIIIIIIII', data[:FDT_HEADER_SIZE])
    assert magic == 0xd00dfeed, f"Bad FDT magic: 0x{magic:08x}"
    print(f"# FDT version={version} total={totalsize} boot_hart={boot_cpuid_phys}")

    FDT_BEGIN_NODE = 1
    FDT_END_NODE   = 2
    FDT_PROP       = 3
    FDT_NOP        = 4
    FDT_END        = 9

    pos = off_dt_struct
    depth = 0
    while pos < off_dt_struct + size_dt_struct:
        tok, = struct.unpack('>I', data[pos:pos+4])
        pos += 4
        if tok == FDT_BEGIN_NODE:
            end = data.index(b'\x00', pos)
            name = data[pos:end].decode('ascii', errors='replace')
            print('  ' * depth + f'node: {name!r}')
            depth += 1
            pos = (end + 4) & ~3
        elif tok == FDT_END_NODE:
            depth -= 1
        elif tok == FDT_PROP:
            plen, pname_off = struct.unpack('>II', data[pos:pos+8])
            pos += 8
            pname_end = data.index(b'\x00', off_dt_strings + pname_off)
            pname = data[off_dt_strings + pname_off:pname_end].decode('ascii', errors='replace')
            val = data[pos:pos+plen]
            pos = (pos + plen + 3) & ~3
            if pname in ('compatible', 'status', 'device_type', 'stdout-path', 'bootargs', 'riscv,isa', 'clock-names', 'label'):
                print('  ' * depth + f'  {pname} = {val.rstrip(b"\x00").decode("ascii", errors="replace")!r}')
            elif plen == 0:
                print('  ' * depth + f'  {pname}')
            elif plen <= 8:
                print('  ' * depth + f'  {pname} = 0x{int.from_bytes(val, "big"):x}')
            elif plen <= 32:
                print('  ' * depth + f'  {pname} = {val.hex()}')
            else:
                print('  ' * depth + f'  {pname} = [{plen} bytes]')
        elif tok == FDT_NOP:
            pass
        elif tok == FDT_END:
            break

if __name__ == '__main__':
    dump_dtb(sys.argv[1] if len(sys.argv) > 1 else '_build/virt.dtb')
