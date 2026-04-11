OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS {
    . = 0x80200000;
    .text : {
        *(.text.start)
        *(.text .text.*)
    }
    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data  .data.*)   }
    .bss    : {
        *(.bss .bss.*)
        *(COMMON)
    }
    /DISCARD/ : { *(*) }
}
