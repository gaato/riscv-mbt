ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 0x20000
}

SECTIONS
{
  .text : ALIGN(4) {
    *(.text.start)
    *(.text*)
    *(.rodata*)
  } > RAM

  .data : ALIGN(4) {
    *(.data*)
  } > RAM

  .bss : ALIGN(4) {
    *(.bss*)
    *(COMMON)
  } > RAM

  .result 0x80003000 : ALIGN(4) {
    __result_addr = .;
    KEEP(*(.result))
  } > RAM

  . = 0x8001f000;
  __stack_top = .;
}
