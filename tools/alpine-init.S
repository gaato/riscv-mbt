    .section .text
    .globl _start

_start:
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

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
    mv s0, a0

    li a0, -100
    la a1, kmsg_path
    li a2, 1
    li a3, 0
    li a7, 56
    ecall
    mv s1, a0

    mv a0, s1
    la a1, exec_failed
    li a2, 34
    li a7, 64
    ecall

    li t0, -2
    beq s0, t0, 2f
    li t0, -8
    beq s0, t0, 3f
    li t0, -13
    beq s0, t0, 4f
    li t0, -14
    beq s0, t0, 5f
    li t0, -26
    beq s0, t0, 6f
    li t0, -12
    beq s0, t0, 7f
    la a1, errno_unknown
    li a2, 19
    j 8f
2:
    la a1, errno_enoent
    li a2, 18
    j 8f
3:
    la a1, errno_enoexec
    li a2, 19
    j 8f
4:
    la a1, errno_eacces
    li a2, 18
    j 8f
5:
    la a1, errno_efault
    li a2, 18
    j 8f
6:
    la a1, errno_etxtbsy
    li a2, 19
    j 8f
7:
    la a1, errno_enomem
    li a2, 18
8:
    mv a0, s1
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
errno_enoent:
    .ascii "exec errno ENOENT\n"
errno_enoexec:
    .ascii "exec errno ENOEXEC\n"
errno_eacces:
    .ascii "exec errno EACCES\n"
errno_efault:
    .ascii "exec errno EFAULT\n"
errno_etxtbsy:
    .ascii "exec errno ETXTBSY\n"
errno_enomem:
    .ascii "exec errno ENOMEM\n"
errno_unknown:
    .ascii "exec errno UNKNOWN\n"
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
