    .section .text
    .globl _start

_start:
    li a0, -100
    la a1, kmsg_path
    li a2, 1
    li a3, 0
    li a7, 56
    ecall

    la a1, marker
    li a2, 33
    li a7, 64
    ecall

    la a0, shell_path
    la a1, argv
    la a2, envp
    li a7, 221
    ecall

    li a0, -100
    la a1, kmsg_path
    li a2, 1
    li a3, 0
    li a7, 56
    ecall

    la a1, exec_failed
    li a2, 34
    li a7, 64
    ecall

1:
    j 1b

    .section .rodata
marker:
    .ascii "riscv-mbt Alpine initramfs ready\n"
marker_end:
exec_failed:
    .ascii "riscv-mbt Alpine init exec failed\n"
exec_failed_end:
shell_path:
    .asciz "/bin/sh"
kmsg_path:
    .asciz "/dev/kmsg"

    .section .data
    .balign 8
argv:
    .dword shell_path
    .dword 0
envp:
    .dword 0
