# RISC-V SimpleOS - Code Walkthrough

## Overview

This document provides detailed explanations of how each major component works, with code references and execution flow diagrams.

---

## 1. Boot Sequence (boot.S)

### Purpose
Initialize the CPU, set up the stack, and jump to the C kernel code.

### Execution Flow

```
CPU Power-On
    ↓
QEMU loads kernel.elf at 0x80000000
    ↓
_start (assembly)
    ↓
Read hartid (CPU ID) from CSR
    ↓
If not CPU 0: park (wait forever)
    ↓
Set up stack pointer (sp) at stack_top
    ↓
Jump to kernel_main() (C code)
```

### Key Code Sections

**Entry Point (boot.S:1-10)**
```asm
.globl _start
_start:
    csrr a0, mhartid      # Read CPU ID (hart ID) into a0
    bnez a0, .park        # If not CPU 0, go to park
    la sp, stack_top      # Load address of stack top into sp
    tail kernel_main      # Jump to kernel_main (no return)
```

**What happens:**
- `csrr a0, mhartid`: Control Status Register Read - reads the machine hartid register into register a0
- `bnez a0, .park`: Branch if Not Equal to Zero - if a0 is not 0 (not CPU 0), jump to park
- `la sp, stack_top`: Load Address - loads the address of stack_top into the stack pointer
- `tail kernel_main`: Tail call (jump without saving return address) to kernel_main in C

**Why this matters:**
- Multi-core systems have multiple CPUs; only one (CPU 0) should boot the OS
- Stack pointer must be set before calling C code (C functions use the stack)
- "tail" is used instead of "call" because kernel_main never returns

### Memory Layout at Boot

```
0x88000000 ┌─────────────────────┐
           │   (RAM END)         │
           │                     │
0x80010000 ├─────────────────────┤ ← __kernel_end (from linker script)
           │   .bss (cleared)    │
           ├─────────────────────┤
           │   .data (globals)   │
           ├─────────────────────┤
           │   .rodata           │
           ├─────────────────────┤
           │   .text (code)      │
0x80000000 └─────────────────────┘ ← Kernel start (QEMU RAM base)
```

**Stack location:** At `stack_top` (defined in linker script kernel.ld)
- Grows downward (toward lower addresses)
- Initially points to top of reserved stack space in .bss section

---

## 2. Kernel Initialization (kernel.c - kernel_main)

### Purpose
Initialize all subsystems in order: BSS, UART, trap handling, memory, processes.

### Execution Flow

```
kernel_main()
    ↓
clear_bss()
    ↓ (Initializes global variables to 0)
    ↓
printf() - Test output
    ↓
trap_init()
    ↓ (Sets up exception handling)
    ↓
pages_init()
    ↓ (Sets up memory allocator)
    ↓
processes_init()
    ↓ (Creates process A and B)
    ↓
start_scheduler()
    ↓ (Enters Process A)
    ↓
(Never returns - processes run forever)
```

### Step-by-Step Explanation

**1. Clear BSS Section (kernel.c:800-810)**
```c
void clear_bss(void) {
    extern uint8_t __bss_start, __bss_end;
    for (uint8_t *p = &__bss_start; p < &__bss_end; p++)
        *p = 0;  // Zero each byte
}
```

**Why:** Uninitialized global variables contain garbage data from previous memory usage. They must be zeroed before use.

**Example:**
```c
static int counter = 0;  // This lives in .data (initialized to 0)
static char buffer[256]; // This lives in .bss (must be cleared)
```

**2. Trap Initialization (kernel.c - trap_init)**
```c
void trap_init(void) {
    extern void trap_vector(void);
    write_csr(mtvec, (uint64_t)trap_vector);
}
```

**What happens:**
- `write_csr(mtvec, ...)`: Writes to the "machine trap vector" CSR
- Tells CPU: "When a trap occurs, jump to trap_vector function"
- trap_vector is written in assembly in boot.S

**3. Memory Initialization (kernel.c - pages_init)**

Creates a linked list of free pages:

```
Free Page List:
┌────────────┐     ┌────────────┐     ┌────────────┐
│ Page 1     │     │ Page 2     │     │ Page 3     │
│ next ──────┼────→│ next ──────┼────→│ next ──────┼──→ NULL
└────────────┘     └────────────┘     └────────────┘
     ↑
free_page_list
```

**Code:**
```c
Page *current = (Page *)free_mem_start;
free_page_list = current;

for (uint64_t i = 0; i < total_pages - 1; i++) {
    Page *next = (Page *)((uint64_t)current + PAGE_SIZE);
    current->next = next;
    current = next;
}
```

**4. Process Initialization (kernel.c - processes_init)**

Creates two process structures with pre-initialized stacks:

```c
processes[0].stack_addr = alloc_page();  // Allocate 4KB for stack
setup_process_stack(0, process_a);       // Set up registers

processes[1].stack_addr = alloc_page();  // Allocate 4KB for stack
setup_process_stack(1, process_b);       // Set up registers
```

**Stack Setup (kernel.c - setup_process_stack):**
```c
void setup_process_stack(int proc_id, void (*entry_point)(void)) {
    uint64_t *stack_top = (uint64_t *)(proc->stack_addr + PAGE_SIZE);
    stack_top -= 13;  // Reserve space for 13 registers
    proc->sp = (uint64_t)stack_top;

    stack_top[0] = (uint64_t)entry_point;  // ra = function address
    for (int i = 1; i < 13; i++)
        stack_top[i] = 0;  // s0-s11 = 0
}
```

**Why 13 registers?**
- ra (return address): Must point to process entry function
- s0-s11 (saved registers): Callee-saved, must be preserved across calls
- These are the only registers that need to be saved for context switching

---

## 3. Trap Handling (trap_vector + trap_handler)

### Purpose
Save CPU state when exceptions/interrupts occur, decode what happened, and handle appropriately.

### Exception Types Handled

```
Exception Code  Name                Handled By
─────────────────────────────────────────────────
0               Instruction align   trap_handler (diagnostic)
1               Instruction fault   trap_handler (diagnostic)
2               Illegal instr       trap_handler (diagnostic)
3               Breakpoint (ebreak) trap_handler (diagnostic)
...
8               ecall (U-mode)      syscall_handler ✓ HANDLED
9               ecall (S-mode)      syscall_handler ✓ HANDLED
11              ecall (M-mode)      syscall_handler ✓ HANDLED
```

### Trap Execution Flow

```
CPU detects exception/interrupt
    ↓
CPU jumps to trap_vector (assembly in boot.S)
    ↓
Save all 32 registers to stack
    ↓
Call trap_handler (C function in kernel.c)
    ↓
trap_handler reads mcause, mepc, mtval CSRs
    ↓
Determines trap type (interrupt vs exception, code number)
    ↓
If ecall: call syscall_handler()
    ↓
Advance mepc by 4 bytes (skip the instruction)
    ↓
Restore all 32 registers from stack
    ↓
mret (return from trap)
    ↓
Execution resumes after trap
```

### Key Code: Trap Vector (boot.S:trap_vector)

```asm
.align 4
.global trap_vector
trap_vector:
    addi sp, sp, -256           # Make room for 32 registers (32 × 8 bytes)

    sd ra, 0(sp)                # Save ra at sp+0
    sd sp, 8(sp)                # Save sp at sp+8
    ...
    sd t6, 240(sp)              # Save t6 at sp+240

    mv a0, sp                   # Load TrapFrame* into a0 (first arg to C)
    call trap_handler           # Call C function

    # Restore all registers (opposite order)
    ld ra, 0(sp)
    ld sp, 8(sp)
    ...
    ld t6, 240(sp)

    addi sp, sp, 256            # Free stack space
    mret                         # Return from trap
```

**Why this matters:**
- Saves ALL registers so C code can inspect them
- TrapFrame struct (in common.h) mirrors this layout exactly
- Uses "sd" (store doubleword) because RISC-V is 64-bit

### Trap Handler Logic (kernel.c - trap_handler)

```c
void trap_handler(TrapFrame *frame) {
    uint64_t cause = read_csr(mcause);
    uint64_t epc = read_csr(mepc);

    uint64_t is_interrupt = (cause >> 63) & 1;
    uint64_t code = cause & 0x3F;

    if (is_interrupt) {
        // Handle interrupt (bit 63 = 1)
    } else if (code == 8 || code == 9 || code == 11) {
        // Handle ecall (system call)
        syscall_handler(frame->a7, frame->a0, frame->a1, frame->a2);
    }

    // Advance PC past the instruction that caused trap
    if (code == 8 || code == 9 || code == 11) {
        uint64_t new_epc = epc + 4;
        write_csr(mepc, new_epc);
    }
}
```

**Critical Detail - Advancing mepc:**
- Without this: CPU re-executes the same `ecall` instruction → infinite loop
- `ecall` is always 4 bytes, so increment by 4
- This is THE FIX that makes syscalls work

---

## 4. System Calls (Syscall Flow)

### Purpose
Allow processes to request kernel services safely (print, file I/O, etc).

### System Call Convention

```
RISC-V Calling Convention:
┌────────┬─────────────────────────────────────┐
│ a7     │ Syscall ID                          │
│ a0     │ First argument (also return value)   │
│ a1     │ Second argument                      │
│ a2     │ Third argument                       │
└────────┴─────────────────────────────────────┘
```

### Complete Syscall Example: SYS_PUTS

**User Code (Process A)**
```c
sys_puts("Hello from Process A!\n");
```

**Syscall Macro (common.h)**
```c
static inline uint64_t syscall(uint64_t id, uint64_t arg0, ...) {
    uint64_t ret;
    asm volatile(
        "mv a7, %1\n"      // a7 = id (SYS_PUTS = 1)
        "mv a0, %2\n"      // a0 = arg0 (pointer to string)
        "mv a1, %3\n"      // a1 = arg1 (unused)
        "mv a2, %4\n"      // a2 = arg2 (unused)
        "ecall\n"          // Trap to kernel
        "mv %0, a0\n"      // ret = a0 (return value)
        : "=r" (ret)
        : "r" (id), "r" (arg0), "r" (arg1), "r" (arg2)
        : "a0", "a1", "a2", "a7"
    );
    return ret;
}
```

**Wrapper Function (kernel.c)**
```c
void sys_puts(const char *s) {
    syscall(SYS_PUTS, (uint64_t)s, 0, 0);
}
```

### Syscall Execution Flow

```
Process A calls sys_puts("Hello")
    ↓
sys_puts() calls syscall() macro
    ↓
Inline asm loads a7=1, a0=pointer_to_string
    ↓
ecall instruction executed
    ↓
CPU detects exception code 11 (ecall)
    ↓
CPU jumps to trap_vector
    ↓
Trap vector saves all registers
    ↓
trap_handler() is called with TrapFrame*
    ↓
trap_handler reads mcause, sees code=11
    ↓
trap_handler calls syscall_handler(frame->a7, frame->a0, ...)
    ↓
syscall_handler(1, pointer_to_string, 0, 0) executes
    ↓
switch (1) { case SYS_PUTS: puts((const char*)pointer); break; }
    ↓
puts() iterates string, calls putchar() for each byte
    ↓
putchar() writes to UART at address 0x10000000
    ↓
Characters appear on console
    ↓
trap_handler advances mepc += 4
    ↓
trap_vector restores all registers
    ↓
mret returns control
    ↓
Process continues after ecall instruction
```

### Syscall Handler Dispatch (kernel.c)

```c
void syscall_handler(uint64_t id, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    switch (id) {
        case SYS_PUTS: {
            const char *s = (const char *)arg0;
            puts(s);
            break;
        }
        case SYS_YIELD: {
            yield();
            break;
        }
        case SYS_OPEN: {
            int fd = fs_open((const char *)arg0);
            break;
        }
        // ... other syscalls
    }
}
```

---

## 5. Memory Management - Page Allocator

### Purpose
Allocate 4KB pages for process stacks and file data.

### Page Structure

```c
typedef struct page {
    struct page *next;  // 8 bytes (pointer to next free page)
} Page;
```

**Memory Layout of a Page:**
```
[0]         [8]              [4096]
└─next──────┴─────────────────┘
  (8 bytes)  (4088 bytes usable)
```

The `next` pointer lives in the first 8 bytes; the rest is free to use.

### Allocation Algorithm

```
Free List State:
free_page_list → [Page 1] → [Page 2] → [Page 3] → NULL

alloc_page():
    if (free_page_list == NULL) return 0;    // Out of memory

    Page *page = free_page_list;             // Get first free page
    free_page_list = page->next;             // Advance list pointer

    memset(page, 0, 4096);                   // Zero-fill page
    return (uint64_t)page;                   // Return address

Free List After alloc_page():
free_page_list → [Page 2] → [Page 3] → NULL
                 [Page 1]  (allocated - returned to caller)
```

### Deallocation Algorithm

```
free_page(page_addr):
    Page *page = (Page *)page_addr;
    page->next = free_page_list;      // Insert at head
    free_page_list = page;            // Update list pointer

Before free_page(Page 1):
free_page_list → [Page 2] → [Page 3] → NULL
[Page 1] (allocated)

After free_page(Page 1):
free_page_list → [Page 1] → [Page 2] → [Page 3] → NULL
                 (returned)
```

### Code (kernel.c)

```c
uint64_t alloc_page(void) {
    if (free_page_list == NULL) {
        printf("ERROR: Out of memory!\n");
        return 0;
    }

    Page *page = free_page_list;
    free_page_list = page->next;
    free_pages--;

    // Zero-fill
    uint8_t *p = (uint8_t *)page;
    for (int i = 0; i < PAGE_SIZE; i++)
        p[i] = 0;

    return (uint64_t)page;
}
```

### Why O(1) Performance?

Both allocation and deallocation are constant-time because:
- Allocation: Take first page from list, update pointer (2 operations)
- Deallocation: Insert at head of list, update pointer (2 operations)
- No searching, no merging, no fragmentation tracking

---

## 6. Context Switching (Cooperative Multitasking)

### Purpose
Switch between Process A and Process B by saving/restoring registers.

### Process States

```
Process A State:
┌──────────────────┐
│ id = 0           │
│ sp = 0x80007ABC  │ ← Points to saved registers on its stack
│ stack_addr =     │
│   0x80007000     │ ← Base of 4KB stack
└──────────────────┘

Process B State:
┌──────────────────┐
│ id = 1           │
│ sp = 0x80008DEF  │ ← Points to saved registers on its stack
│ stack_addr =     │
│   0x80008000     │ ← Base of 4KB stack
└──────────────────┘
```

### Context Switch Flow

```
Process A executing
    ↓ (calls yield())
    ↓
yield() calls switch_context(&proc_A.sp, &proc_B.sp)
    ↓
switch_context (assembly in boot.S):
  1. Save current sp to &proc_A.sp (writes to memory)
  2. Save all callee-saved registers to stack:
     ra, s0, s1, ..., s11
  3. Load sp from &proc_B.sp (reads from memory)
  4. Restore all callee-saved registers from new stack:
     ra, s0, s1, ..., s11
  5. Return (via restored ra)
    ↓
Current processor returns to Process B code
    ↓
Process B executing (after yield() call completed)
```

### Stack Layout During Context Switch

**Process A Stack (before switch_context)**
```
(high addresses)
0x80007000 + 4096 = 0x80008000
...
0x80007ABC ← sp (stack pointer) points here
[ra] (Process A code location to resume)
[s0]
[s1]
...
[s11]
(low addresses)
```

**Process B Stack (after switch_context)**
```
(high addresses)
0x80008000 + 4096 = 0x80009000
...
0x80008DEF ← sp now points here
[ra] (Process B code location to resume)
[s0]
[s1]
...
[s11]
(low addresses)
```

### Switch Context Code (boot.S)

```asm
.global switch_context
switch_context:
    # a0 = &current_process->sp
    # a1 = &next_process->sp

    # Save current sp to memory
    sd sp, 0(a0)

    # Make room for 13 registers (ra + s0-s11)
    addi sp, sp, -104

    # Save all callee-saved registers
    sd ra, 0(sp)
    sd s0, 8(sp)
    ...
    sd s11, 96(sp)

    # Update current->sp with new position
    sd sp, 0(a0)

    # Load next process's sp
    ld sp, 0(a1)

    # Restore next process's registers
    ld ra, 0(sp)
    ld s0, 8(sp)
    ...
    ld s11, 96(sp)

    # Free stack space
    addi sp, sp, 104

    # Return to process B (via restored ra)
    ret
```

### Why Only Callee-Saved Registers?

RISC-V calling convention:
- **Caller-saved** (a0-a7, t0-t6): Caller must save if needed
- **Callee-saved** (s0-s11, ra): Callee must save/restore if used

Process A → yield() → switch_context():
- yield() is the "callee" (called by Process A)
- yield() must preserve all registers that Process A uses
- Process A only uses s0-s11 as callee-saved
- So switch_context saves/restores s0-s11 and ra

---

## 7. File System - Inode-Based

### Purpose
Provide file creation, reading, writing, and deletion for processes.

### Inode Table

```c
typedef struct {
    char filename[MAX_FILENAME];  // File name (64 bytes)
    uint64_t size;                // File size in bytes
    uint64_t data_addr;           // Address of 4KB data page
    int in_use;                   // 0=free, 1=allocated
} Inode;

static Inode inode_table[MAX_INODES];  // Up to 16 files
```

### Memory Layout: File "hello.txt" with content "Hello"

```
Inode Table (in kernel memory)
┌──────────────────────┐
│ [0]                  │
│ filename: "hello.txt"│
│ size: 5              │
│ data_addr: 0x80010000│ ← Points here
│ in_use: 1            │
└──────────────────────┘

File Data (4KB page allocated by page allocator)
0x80010000 ┌──────────────────┐
           │ [0]='H'          │
           │ [1]='e'          │
           │ [2]='l'          │
           │ [3]='l'          │
           │ [4]='o'          │
           │ [5-4095] unused  │
           └──────────────────┘
0x80014000 (end of page)
```

### File Operations

#### fs_open("hello.txt")

```
Does file exist?
    ↓ No: Create new inode
    ↓
Find free inode slot in table
    ↓
Allocate 4KB page via alloc_page()
    ↓
Initialize inode:
  filename = "hello.txt"
  size = 0
  data_addr = <allocated page>
  in_use = 1
    ↓
Return inode index (0-15)
```

#### fs_write(fd, "Hello", 5)

```
Get inode from fd
    ↓
Get data_addr from inode
    ↓
Cast to uint8_t* pointer
    ↓
Copy 5 bytes:
  data[0] = 'H'
  data[1] = 'e'
  data[2] = 'l'
  data[3] = 'l'
  data[4] = 'o'
    ↓
Update inode->size = 5
    ↓
Return 5 (bytes written)
```

#### fs_read(fd, buffer, 256)

```
Get inode from fd
    ↓
Get size and data_addr from inode
    ↓
Copy min(256, size) bytes to buffer:
  for (i = 0; i < bytes_to_read; i++)
    buffer[i] = data[i]
    ↓
Return bytes_to_read
```

#### fs_unlink("hello.txt")

```
Find inode by name
    ↓ (fs_find_inode iterates table)
    ↓
Found at index 0
    ↓
Free data page: free_page(inode->data_addr)
    ↓
Mark inode unused: inode->in_use = 0
    ↓
Return 0 (success)
```

### File Persistence

Files persist because:
1. Inode table is global static array in kernel memory
2. Data pages are in kernel heap (allocated via page allocator)
3. Both survive process context switches
4. Process A creates file → Process B can read it

```
Process A execution:
  fd = fs_open("hello.txt")
  fs_write(fd, "data", 4)
    ↓ (inode created, data written)

Process B execution:
  fd = fs_open("hello.txt")  ← Same inode found!
  fs_read(fd, buf, 256)       ← Reads "data"
```

### Multi-Process Access

Both processes share same inode_table and free_page_list:

```
Shared Kernel Memory:
┌─────────────────────────────┐
│ inode_table[0-15]           │ ← Both processes see same files
│ free_page_list              │
│ current_process             │
│ processes[0], processes[1]  │
└─────────────────────────────┘

Process A Stack     Process B Stack
(separate 4KB)      (separate 4KB)
```

---

## Execution Timeline Example

```
Time T0: kernel_main() starts
├─ clear_bss()
├─ printf("Boot sequence started")
├─ trap_init()
├─ pages_init()
├─ processes_init()
│  ├─ alloc_page() → 0x80007000 (Process A stack)
│  ├─ setup_process_stack(0, process_a)
│  │  └─ Process A's sp = 0x80007068
│  ├─ alloc_page() → 0x80008000 (Process B stack)
│  └─ setup_process_stack(1, process_b)
│     └─ Process B's sp = 0x80008068
└─ start_scheduler(&processes[0].sp)
   └─ Enters Process A

Time T1: Process A executing
├─ sys_puts("Process A starting...")
│  └─ Triggers trap, syscall_handler handles, prints output
├─ fd = fs_open("file_a.txt")
│  └─ alloc_page() → 0x80009000 (file data)
├─ fs_write(fd, "Hello from A!", 13)
│  └─ inode->size = 13
└─ sys_yield()
   └─ Calls switch_context(&processes[0].sp, &processes[1].sp)

Time T2: Context switch
├─ save Process A's sp, registers
├─ load Process B's sp, registers
└─ Execution resumes in Process B

Time T3: Process B executing
├─ sys_puts("Process B starting...")
├─ fd = fs_open("file_a.txt")
│  └─ Inode found! (from Process A)
├─ fs_read(fd, buf, 256)
│  └─ Reads "Hello from A!" from same page
└─ sys_yield()
   └─ Switches back to Process A

Time T4: Back to Process A (T1 loop)
├─ sys_puts("Process A again...")
└─ sys_yield()
   └─ Loop continues forever...
```

---

## Key Takeaways

1. **Boot**: CPU starts, sets stack, jumps to C code
2. **Init**: Clears BSS, sets up traps, memory, processes
3. **Traps**: CPU saves state, calls handler, resumes after
4. **Syscalls**: ecall → trap → syscall_handler → service → return
5. **Memory**: Linked-list page allocator, O(1) alloc/free
6. **Context Switch**: Save/restore callee-saved registers only
7. **Files**: Inode-based, shared across processes, use page allocator

All components work together to provide a minimal but functional OS!
