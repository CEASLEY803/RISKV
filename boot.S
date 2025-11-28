.section .text.boot
.global _start

_start:
    # 1. Read the Hardware Thread ID (hartid) into register a0
    csrr a0, mhartid

    # 2. We only want Core 0 to boot the kernel.
    #    If mhartid != 0, jump to an infinite loop (park the core).
    bnez a0, .park

    # 3. Setup the Stack Pointer (sp).
    #    We will use a small stack space defined at the bottom of this file.
    la sp, stack_top

    # 4. Jump to the C function 'kernel_main'
    #    'tail' is an optimization that jumps without expecting a return.
    tail kernel_main

.park:
    # Put the core into a low-power wait loop
    wfi
    j .park

# -------------------------------------------------------------------
# Trap Vector (The "Save Game" point)
# When a trap occurs, the CPU jumps here to save state and handle it
# -------------------------------------------------------------------
.align 4
.global trap_vector
trap_vector:
    # 1. Decrease stack pointer to make room for 32 registers (8 bytes each)
    addi sp, sp, -256

    # 2. Save all General Purpose Registers (GPRs)
    sd ra, 0(sp)
    sd sp, 8(sp)
    sd gp, 16(sp)
    sd tp, 24(sp)
    sd t0, 32(sp)
    sd t1, 40(sp)
    sd t2, 48(sp)
    sd s0, 56(sp)
    sd s1, 64(sp)
    sd a0, 72(sp)
    sd a1, 80(sp)
    sd a2, 88(sp)
    sd a3, 96(sp)
    sd a4, 104(sp)
    sd a5, 112(sp)
    sd a6, 120(sp)
    sd a7, 128(sp)
    sd s2, 136(sp)
    sd s3, 144(sp)
    sd s4, 152(sp)
    sd s5, 160(sp)
    sd s6, 168(sp)
    sd s7, 176(sp)
    sd s8, 184(sp)
    sd s9, 192(sp)
    sd s10, 200(sp)
    sd s11, 208(sp)
    sd t3, 216(sp)
    sd t4, 224(sp)
    sd t5, 232(sp)
    sd t6, 240(sp)

    # 3. Call the C trap handler
    #    Pass the pointer to the saved registers as argument (in a0)
    mv a0, sp
    call trap_handler

    # 4. Restore all registers
    ld ra, 0(sp)
    ld sp, 8(sp)
    ld gp, 16(sp)
    ld tp, 24(sp)
    ld t0, 32(sp)
    ld t1, 40(sp)
    ld t2, 48(sp)
    ld s0, 56(sp)
    ld s1, 64(sp)
    ld a0, 72(sp)
    ld a1, 80(sp)
    ld a2, 88(sp)
    ld a3, 96(sp)
    ld a4, 104(sp)
    ld a5, 112(sp)
    ld a6, 120(sp)
    ld a7, 128(sp)
    ld s2, 136(sp)
    ld s3, 144(sp)
    ld s4, 152(sp)
    ld s5, 160(sp)
    ld s6, 168(sp)
    ld s7, 176(sp)
    ld s8, 184(sp)
    ld s9, 192(sp)
    ld s10, 200(sp)
    ld s11, 208(sp)
    ld t3, 216(sp)
    ld t4, 224(sp)
    ld t5, 232(sp)
    ld t6, 240(sp)

    # 5. Free stack space
    addi sp, sp, 256

    # 6. Return from Trap (Restores previous PC and privilege mode)
    mret

# ============================================================================
# Context Switching - switch_context(uint64_t *sp_ptr)
# ============================================================================
# This function switches from the current process to another process.
# It saves callee-saved registers and the return address to the current stack,
# then loads a new stack pointer and restores the other process's registers.
#
# RISC-V Calling Convention:
# - a0 = first argument (pointer to stack pointer to load from)
# - ra = return address
# Callee-saved registers that we must preserve: s0-s11, ra, sp
#
# The stack layout after saving:
# sp+0:   ra (return address)
# sp+8:   s0
# sp+16:  s1
# ... (s2-s11)
# sp+96:  sp (saved stack pointer, used to restore)
.global switch_context
switch_context:
    # a0 = &current_process->sp (pointer to where to save current sp)
    # First, save the current stack pointer to its location
    sd sp, 0(a0)

    # Now save callee-saved registers to the current stack
    addi sp, sp, -104      # Allocate space for 13 registers (ra + s0-s11)
    sd ra, 0(sp)
    sd s0, 8(sp)
    sd s1, 16(sp)
    sd s2, 24(sp)
    sd s3, 32(sp)
    sd s4, 40(sp)
    sd s5, 48(sp)
    sd s6, 56(sp)
    sd s7, 64(sp)
    sd s8, 72(sp)
    sd s9, 80(sp)
    sd s10, 88(sp)
    sd s11, 96(sp)

    # Update the current_process->sp with the new stack pointer
    sd sp, 0(a0)

    # Now we need to get the next process's stack pointer
    # a1 contains the pointer to the NEXT process's sp
    ld sp, 0(a1)         # Load the next process's stack pointer

    # Restore callee-saved registers from the next process's stack
    ld ra, 0(sp)
    ld s0, 8(sp)
    ld s1, 16(sp)
    ld s2, 24(sp)
    ld s3, 32(sp)
    ld s4, 40(sp)
    ld s5, 48(sp)
    ld s6, 56(sp)
    ld s7, 64(sp)
    ld s8, 72(sp)
    ld s9, 80(sp)
    ld s10, 88(sp)
    ld s11, 96(sp)

    addi sp, sp, 104      # Free the stack space

    # Jump to the next process's return address (which is now in ra)
    ret

# ============================================================================
# start_scheduler - Bootstrap into the first process
# ============================================================================
# This function loads a process's pre-initialized stack and jumps into it.
# It's used to enter the first process from kernel_main.
#
# Arguments:
# - a0 = pointer to the process's sp to load
.global start_scheduler
start_scheduler:
    # Load the process's stack pointer
    ld sp, 0(a0)

    # Restore the return address (which was set to the entry function)
    ld ra, 0(sp)

    # Restore all callee-saved registers
    ld s0, 8(sp)
    ld s1, 16(sp)
    ld s2, 24(sp)
    ld s3, 32(sp)
    ld s4, 40(sp)
    ld s5, 48(sp)
    ld s6, 56(sp)
    ld s7, 64(sp)
    ld s8, 72(sp)
    ld s9, 80(sp)
    ld s10, 88(sp)
    ld s11, 96(sp)

    # Adjust stack pointer
    addi sp, sp, 104

    # Jump to the entry function (address in ra)
    ret

.section .bss
    # Allocate 4KB (4096 bytes) of stack space per core (minimal setup)
    .space 4096 * 4
    .global stack_top
stack_top: