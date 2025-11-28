# RISC-V SimpleOS

A minimal educational operating system for the RISC-V architecture. This project demonstrates the fundamentals of OS development including boot sequence, memory management, trap handling, multitasking, and system calls.

## Overview

This is an educational project designed to teach the basics of operating system development on the RISC-V instruction set architecture. It includes a bootloader, kernel initialization, a simple UART driver for console output, trap handling, memory management, cooperative multitasking, and a system call interface.

## Project Structure

```text
myos/
├── boot.S          # Assembly boot code - CPU startup, context switching, trap vector
├── kernel.c        # Main kernel code with printf, panic, memory, processes, syscalls
├── kernel.ld       # Linker script - defines memory layout and BSS symbols
├── common.h        # Common header - type definitions, macros, syscall interface
├── makefile        # Build configuration
└── readme.md       # This file
```

### Key Components

- **boot.S** - The entry point for the kernel. Initializes the CPU, sets up the stack, and jumps to `kernel_main`. Includes trap vector for exception handling and context switching functions for multitasking.
- **kernel.c** - Contains kernel initialization, UART driver, printf implementation, panic function, BSS clearing, page allocator, process management, trap handler, and syscall handler.
- **kernel.ld** - GNU linker script that maps the kernel to QEMU's RAM base (0x80000000) and organizes sections (.text, .rodata, .data, .bss). Exports `__bss_start` and `__bss_end` symbols.
- **common.h** - Header file with standard integer type definitions, CSR macros, syscall interface, and trap frame structure.
- **makefile** - Automates compilation and running in QEMU.

## Project Status

### Completed (Step 1: Initialization)

- ✅ Basic project structure
- ✅ Boot assembly (`boot.S`) - CPU startup and stack initialization
- ✅ Kernel implementation (`kernel.c`) - Primitive UART driver for console output
- ✅ Linker script (`kernel.ld`) - Maps kernel to 0x80000000 (QEMU RAM base)

### Completed (Step 2: Building Tools - printf)

- ✅ Common header file (`common.h`) - Standard integer type definitions
- ✅ Printf implementation - Supports %s (string), %d (decimal), %x (hex)
- ✅ BSS clearing - Zero-initializes global variables
- ✅ Panic function - Halts kernel with error message
- ✅ Enhanced console output - Test output with formatted numbers

### Completed (Step 3: Trap Handling - Interrupts & Exceptions)

- ✅ CSR (Control Status Register) macros - Read/write hardware registers from C
- ✅ Trap vector assembly (`trap_vector`) - Saves all 32 registers to stack
- ✅ Trap frame structure - C struct matching register save layout
- ✅ Trap initialization (`trap_init`) - Sets up mtvec register (machine mode)
- ✅ Trap handler (`trap_handler`) - Decodes and logs trap information
- ✅ Exception code decoding - Identifies instruction faults, access violations, etc.

### Completed (Step 4: Memory Management - Page Allocator)

- ✅ Page structure - Linked list node for free pages
- ✅ Page allocator (`alloc_page`) - Allocates single 4KB pages from free list
- ✅ Page deallocation (`free_page`) - Returns pages to free list
- ✅ Memory initialization (`pages_init`) - Builds linked list of available RAM
- ✅ Page testing (`mem_test`) - Verifies allocator functionality

### Completed (Step 5: Cooperative Multitasking - Context Switching)

- ✅ Process Control Block (PCB) - Structure to track process state and stack pointer
- ✅ Process stack setup (`setup_process_stack`) - Initializes process stacks with forged register frames
- ✅ Context switching (`switch_context`) - Assembly function to save/restore callee-saved registers
- ✅ Process bootstrap (`start_scheduler`) - Assembly function to enter first process safely
- ✅ Yield mechanism (`yield`) - Voluntarily gives up CPU in round-robin fashion
- ✅ Process initialization (`processes_init`) - Creates and configures processes A and B
- ✅ Multiple processes - Two concurrent processes alternating execution

### Completed (Step 6: System Calls - User/Kernel Transition)

- ✅ Syscall interface (`syscall` macro) - Inline assembly to execute ecall instruction
- ✅ Syscall definitions - SYS_PUTS (ID 1) and SYS_YIELD (ID 2)
- ✅ Syscall handler (`syscall_handler`) - Dispatches syscalls to kernel functions
- ✅ Trap integration - trap_handler dispatches ecalls to syscall_handler
- ✅ SYS_PUTS syscall - Process can request kernel to print strings
- ✅ SYS_YIELD syscall - Process can request to yield control via ecall
- ✅ Syscall wrappers (`sys_puts`, `sys_yield`) - User-friendly syscall interface
- ✅ Protection layer - Processes transition to kernel mode via ecall instruction

### Completed (Step 7: File System - RAM-Based)

- ✅ File system structures - Inode (file metadata) and FileDescriptor (open file handle)
- ✅ Inode table - Manages up to 16 files simultaneously
- ✅ File operations - Open (create if needed), close, read, write, delete
- ✅ File allocation - Each file gets one 4KB page of memory
- ✅ File syscalls:
  - `SYS_OPEN` (ID 3) - Open or create a file, returns file descriptor
  - `SYS_CLOSE` (ID 4) - Close an open file
  - `SYS_READ` (ID 5) - Read bytes from a file
  - `SYS_WRITE` (ID 6) - Write bytes to a file
  - `SYS_UNLINK` (ID 7) - Delete a file and free its memory
  - `SYS_LIST` (ID 8) - List all files in the filesystem
- ✅ File persistence - Data persists across context switches and process yields
- ✅ Multiple process access - Different processes can create, read, and modify files
- ✅ Simple memory management - Integrates with existing page allocator

## Requirements

You need a RISC-V cross-compiler and QEMU to build and run this project on a lab machine.

### Lab Machine Setup (Ubuntu/Debian - Copy & Paste)

**Step 1: Update package list**
```bash
sudo apt update
```

**Step 2: Install RISC-V compiler and QEMU**
```bash
sudo apt install -y gcc-riscv64-unknown-elf qemu-system-misc make
```

**Step 3: Verify installation**
```bash
# Check compiler
riscv64-unknown-elf-gcc --version

# Check QEMU
qemu-system-riscv64 --version

# Check make
make --version
```

Expected output:
```
riscv64-unknown-elf-gcc (GCC) 13.2.0
QEMU emulator version 8.x.x
GNU Make 4.x
```

**Alternative compiler** (if the above packages aren't available in your repo):
```bash
sudo apt install -y gcc-riscv64-linux-gnu qemu-system-misc make
# Then use: riscv64-linux-gnu-gcc instead of riscv64-unknown-elf-gcc
```

## Building and Running

### Quick Start (3 commands)
```bash
# Clone or navigate to the myos directory
cd myos

# Build the kernel
make

# Run in QEMU
make run
```

Expected build output:
```
riscv64-unknown-elf-gcc -Wall -Wextra -O2 -g -mcmodel=medany -ffreestanding -nostdlib -c kernel.c -o kernel.o
riscv64-unknown-elf-gcc -Wall -Wextra -O2 -g -mcmodel=medany -ffreestanding -nostdlib -c boot.S -o boot.o
riscv64-unknown-elf-gcc -T kernel.ld -o kernel.elf -Wall -Wextra -O2 -g -mcmodel=medany -ffreestanding -nostdlib kernel.o boot.o
```

### Run in QEMU
QEMU will launch in text mode. You should see output like:
```
================================
RISC-V SimpleOS - Boot Sequence
================================
Kernel loaded at address: 0x80000000
Test Math: 10 + 20 = 30
Test Hex:  255 = 0x000000ff

[1] Initializing trap handling...
Trap handler initialized at 0x80002e30

[2] Initializing memory manager...

--- Memory Manager Initialized ---
Kernel end:    0x80010000
Free mem:      0x80011000
RAM end:       0x88000000
Total pages:   32767 KB

[3] Initializing process manager...

--- Initializing Process Manager ---
Created Process A...
Created Process B...
Process Manager ready. Starting scheduler...

[4] Starting scheduler...
================================

Process A: Creating file_a.txt...
Process A: Wrote to file_a.txt

--- File List ---
[0] file_a.txt (21 bytes)
-----------------

Process B: Opening file_a.txt...
Process B: Read from file_a.txt: 'Hello from Process A!'
Process B: Creating file_b.txt...
Process B: Wrote to file_b.txt

--- File List ---
[0] file_a.txt (21 bytes)
[1] file_b.txt (19 bytes)
-----------------
```

### Interacting with the Kernel

Once QEMU starts, the kernel runs automatically and displays all output to the console. The system demonstrates:

1. **Boot sequence** - Kernel initialization and subsystem startup
2. **Trap handling** - CPU exception handling infrastructure
3. **Memory management** - Page allocator initialization
4. **Process management** - Two concurrent processes
5. **File system** - Inter-process file creation and reading

The output streams continuously as Process A and Process B alternate execution. No user input is needed—the system demonstrates all features automatically.

### Exit QEMU
**Option 1: Use keyboard shortcut**
```
Ctrl+A, then release, then press X
```

**Option 2: Use QEMU monitor (advanced)**
```
Ctrl+A, then release, then press C     (opens monitor)
(qemu) quit                            (type quit and press Enter)
```

**Option 3: Force quit if stuck**
```
Ctrl+C in the terminal
```

### Cleaning Up

To remove build artifacts and rebuild:
```bash
make clean
make
make run
```

## Troubleshooting

### Installation Issues

**Problem: Command not found: gcc-riscv64-unknown-elf**

Solution 1: Try the alternative compiler
```bash
sudo apt install gcc-riscv64-linux-gnu
# Edit makefile to use: riscv64-linux-gnu-gcc instead
```

Solution 2: Add to repository
```bash
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt update
sudo apt install gcc-riscv64-unknown-elf qemu-system-misc
```

**Problem: qemu-system-riscv64: command not found**

```bash
# Install QEMU
sudo apt install qemu-system-misc

# Or install full QEMU
sudo apt install qemu-system
```

**Problem: make: command not found**

```bash
sudo apt install build-essential
```

### Build Issues

**Problem: Assembler Error - "no such instruction"**

Error message: `boot.s: Error: no such instruction: 'csrr a0,mhartid'`

Cause: The boot file is named `boot.s` (lowercase) instead of `boot.S` (uppercase). The Makefile uses the RISC-V compiler for `.S` files but falls back to the generic `as` for lowercase `.s` files, which doesn't understand RISC-V instructions.

Solution: Ensure the assembly file is named `boot.S` (uppercase).

**Problem: Linker Error - "syntax error"**

Error message: `kernel.ld:12: syntax error`

Cause: The linker script uses invalid syntax like `(.text .text.)` instead of `*(.text .text.*)`. GNU linker scripts require the `*()` wildcard pattern.

Solution: Check `kernel.ld` uses correct pattern: `*(.section_name .section_name.*)`

**Problem: Compilation warnings about implicit declarations**

Example: `warning: implicit declaration of function 'fs_open'`

This is normal—forward declarations are used to avoid circular dependencies. The code compiles and runs correctly despite the warnings.

## How It Works

### 1. Boot Phase (`boot.S`)
   - CPU starts execution at 0x80000000 (QEMU virt machine RAM base)
   - Stack is initialized
   - Jumps to `kernel_main()` in C

### 2. Kernel Initialization (`kernel.c`)
   - Clears .bss section (zero-initializes global variables)
   - Initializes UART for console output
   - Uses printf() for formatted console output
   - Initializes trap handling (sets up mtvec register)
   - Initializes memory allocator with available RAM
   - Initializes process manager with two test processes

### 3. Process Management (`kernel.c` + `boot.S`)
   - Allocates 4KB pages for each process stack
   - Creates fake register frames on stacks (process stacks pre-initialized)
   - Enters first process via `start_scheduler` assembly function
   - Processes execute cooperatively, yielding control voluntarily
   - Context switching saves/restores callee-saved registers

### 4. Trap Handling (`boot.S` + `kernel.c`)
   - When an interrupt or exception occurs, CPU jumps to `trap_vector`
   - Assembly saves all 32 registers to the stack (TrapFrame)
   - C handler examines mcause, mepc, and mtval registers (machine mode)
   - Decodes exception type (fault, illegal instruction, breakpoint, ecall, etc.)
   - For ecall (system call), dispatches to `syscall_handler`
   - Prints diagnostic information and either continues or panics

### 5. System Calls (User Mode)
   - Process calls `sys_puts()` or `sys_yield()` function
   - These functions execute inline assembly to:
     - Load syscall ID into a7 register
     - Load arguments into a0, a1, a2 registers
     - Execute `ecall` instruction
   - CPU traps to kernel with exception code 8/9/11 (ecall)
   - `trap_handler` detects ecall and calls `syscall_handler`
   - `syscall_handler` examines frame->a7 for syscall ID and dispatches
   - Kernel executes requested function and returns via mret

### 6. Memory Layout (`kernel.ld`)
   - Text segment (.text) at 0x80000000 - contains executable code
   - Read-only data (.rodata) - constants
   - Initialized data (.data) - global variables with values
   - Uninitialized data (.bss) - zero-filled memory (cleared by kernel)
   - Heap - managed by page allocator

## Key Features

### Printf Implementation
A minimal printf implementation that supports:
- `%s` - String arguments
- `%d` - Decimal signed integers (including negative)
- `%x` - Hexadecimal (8-digit, zero-padded)
- `%%` - Literal percent sign

This is implemented in bare metal without linking the standard library, using a variadic argument list to access arguments.

### BSS Clearing
Before any global variables are used, the `.bss` section is cleared (set to zero). This is important because:
- Uninitialized global variables need deterministic values
- The linker places symbols `__bss_start` and `__bss_end` for this purpose
- The kernel manually clears this memory during startup

### Panic Function
A kernel panic mechanism that prints an error message and halts the system using the `wfi` (Wait For Interrupt) instruction. Used when unrecoverable errors occur.

### Page Allocator
A simple linked-list based page allocator that:
- Manages 4KB pages of RAM
- Uses first 8 bytes of each page to store free list pointer
- Allocates and deallocates pages in O(1) time
- Provides page testing functionality

### Cooperative Multitasking
Two processes (Process A and B) execute cooperatively:
- Each process has its own 4KB stack
- Register state is saved/restored across context switches
- Processes voluntarily yield control to each other
- Round-robin scheduling alternates between processes
- Supports up to MAX_PROCESSES (currently 2) concurrent processes

### System Call Interface
Provides a protected transition from user code to kernel:
- Syscalls are dispatched via exception handlers (ecall)
- Syscall IDs and arguments passed via registers (a7 for ID, a0-a2 for args)
- Kernel validates and executes requested operations
- Returns control to user process after completing syscall
- Syscalls implemented:
  - `SYS_PUTS` (1) - Print string
  - `SYS_YIELD` (2) - Yield CPU to next process
  - `SYS_OPEN` (3) - Open/create file
  - `SYS_CLOSE` (4) - Close file
  - `SYS_READ` (5) - Read from file
  - `SYS_WRITE` (6) - Write to file
  - `SYS_UNLINK` (7) - Delete file
  - `SYS_LIST` (8) - List all files

### File System (RAM-Based)

A simple in-memory file system for storing and retrieving data:

- **Inode-based design** - Each file has metadata (name, size, data pointer)
- **16 maximum files** - Supports up to 16 concurrent files in system
- **4KB per file** - Each file allocated one 4KB page of RAM
- **File operations**:
  - **Open** - Create new file or open existing file (non-destructive)
  - **Read** - Read entire file content into buffer
  - **Write** - Write buffer to file (overwrites previous content)
  - **Close** - Releases file descriptor (simplified version)
  - **Delete** - Remove file and free its allocated page
  - **List** - Display all files with names and sizes
- **Data persistence** - Files remain in memory across context switches
- **Multi-process access** - Different processes can read/write same files
- **Page integration** - Uses existing page allocator for storage

## Implementation Details

### Inline Assembly for Syscalls
```c
static inline uint64_t syscall(uint64_t id, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret;
    asm volatile(
        "mv a7, %1\n"      // Move syscall ID to a7
        "mv a0, %2\n"      // Move arg0 to a0
        "mv a1, %3\n"      // Move arg1 to a1
        "mv a2, %4\n"      // Move arg2 to a2
        "ecall\n"          // Execute syscall
        "mv %0, a0\n"      // Move return value from a0
        : "=r" (ret)
        : "r" (id), "r" (arg0), "r" (arg1), "r" (arg2)
        : "a0", "a1", "a2", "a7"
    );
    return ret;
}
```

### Context Switch Register Layout
Process stacks store 13 registers (callee-saved):
```
Stack Frame (from low to high address):
  [0]  ra  (return address)
  [1]  s0  (saved register 0)
  ...
  [11] s11 (saved register 11)
```

Total: 13 × 8 bytes = 104 bytes per context switch frame

## Architecture Notes

This project demonstrates several OS concepts on RISC-V:
- **Machine Mode**: QEMU boots in machine mode (not user/supervisor mode)
- **Trap Vectors**: Exception handling via mtvec CSR (machine trap vector)
- **Calling Convention**: RISC-V uses register-based calling convention (a0-a7 for args, s0-s11 callee-saved)
- **Inline Assembly**: Syscalls implemented via inline asm to execute ecall instruction
- **Register Frames**: Process stacks contain forged register save frames for context switching
- **Ring 0 Code**: All code runs in machine mode (no privilege separation in this simple OS)

## Future Enhancements

Potential features that could be added:

**Storage & Persistence**:

- Persistent block device storage (VirtIO or simple disk simulator)
- Multi-page files with block allocation
- Directory structure and hierarchical paths
- File permissions and access control

**Process Management**:

- Timer interrupts for preemptive multitasking
- Dynamic process creation (fork system call)
- Process termination (exit system call)
- Process scheduling with priorities
- Parent-child process relationships

**Advanced Features**:

- Virtual memory with paging
- User mode privilege level (supervisor mode)
- Synchronization primitives (locks, mutexes, semaphores)
- Inter-process communication (IPC, pipes)
- Signal handling
- Standard input/output redirection

## References

- [RISC-V Instruction Set Manual](https://riscv.org/technical/specifications/)
- [RISC-V Privileged Spec](https://riscv.org/technical/specifications/)
- [QEMU RISC-V Documentation](https://wiki.qemu.org/Documentation/Platforms/RISC-V)
- RISC-V Calling Convention (LP64 ABI)
- [Linux Kernel Documentation on Syscalls](https://www.kernel.org/doc/html/latest/)
