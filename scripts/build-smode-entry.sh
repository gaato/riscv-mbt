#!/bin/sh
# Build the minimal S-mode entry stub for riscv-mbt Task 0015.
# Output: _build/smode-entry.bin (raw binary at 0x80200000)

set -e
cd "$(dirname "$0")/../.."

CC=riscv64-elf-gcc
OBJCOPY=riscv64-elf-objcopy

$CC \
    -march=rv64imac_zicsr_zifencei \
    -mabi=lp64 \
    -nostdlib \
    -nodefaultlibs \
    -static \
    -T tools/c-samples/smode-entry/smode_entry.lds \
    -o _build/smode-entry.elf \
    tools/c-samples/smode-entry/smode_entry.S

$OBJCOPY -O binary _build/smode-entry.elf _build/smode-entry.bin

echo "Built _build/smode-entry.bin ($(wc -c < _build/smode-entry.bin) bytes)"
