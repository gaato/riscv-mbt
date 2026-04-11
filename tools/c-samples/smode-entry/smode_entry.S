/* Minimal S-mode kernel entry stub for riscv-mbt Task 0015.
 *
 * OpenSBI jumps here in S-mode with:
 *   a0 = hart_id
 *   a1 = DTB physical address
 *   satp = 0  (bare physical addressing)
 *
 * This stub verifies the boot ABI by writing a banner to UART and spinning.
 */

.section .text.start
.align 2
.globl _start
_start:
    /* Store a0/a1 for later retrieval */
    mv   s0, a0          /* hart_id */
    mv   s1, a1          /* dtb_ptr */

    /* Print banner via UART at 0x10000000 */
    li   t0, 0x10000000  /* UART THR */
    la   t1, banner
1:  lbu  t2, 0(t1)
    beqz t2, 2f
    sb   t2, 0(t0)
    addi t1, t1, 1
    j    1b

    /* Spin (infinite loop) */
2:  j    2b

banner:
    .asciz "\r\nLinux ABI: S-mode entry OK\r\n"
    .align 2
