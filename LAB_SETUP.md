# RISC-V SimpleOS - Lab Setup Guide

## Quick Start (For Impatient Lab Machines)

```bash
# 1. Run automated setup
bash setup-lab.sh

# 2. Build the kernel
make

# 3. Run in QEMU
make run

# 4. To exit: Ctrl+A, then X
```

## Detailed Lab Setup Steps

### Step 1: Prepare Your Lab Machine

You need a Ubuntu/Debian lab machine with sudo access.

### Step 2: Install Required Tools

**Option A: Automated (Easiest)**
```bash
cd myos
bash setup-lab.sh
```

The script will:
- Update package list
- Install RISC-V compiler (gcc-riscv64-unknown-elf)
- Install QEMU emulator
- Install build tools (make)
- Verify all installations

**Option B: Manual Installation**
```bash
# Update packages
sudo apt update

# Install tools
sudo apt install -y gcc-riscv64-unknown-elf qemu-system-misc make

# Verify installation
riscv64-unknown-elf-gcc --version
qemu-system-riscv64 --version
make --version
```

**Option C: If packages unavailable**
```bash
sudo apt install -y gcc-riscv64-linux-gnu qemu-system-misc make
```

### Step 3: Build the Kernel

```bash
cd myos
make
```

Expected output:
```
riscv64-unknown-elf-gcc -Wall -Wextra -O2 -g -mcmodel=medany -ffreestanding -nostdlib -c kernel.c -o kernel.o
riscv64-unknown-elf-gcc -Wall -Wextra -O2 -g -mcmodel=medany -ffreestanding -nostdlib -c boot.S -o boot.o
riscv64-unknown-elf-gcc -T kernel.ld -o kernel.elf ...
```

**Note:** Compilation warnings about implicit declarations are expected and safe to ignore.

### Step 4: Run in QEMU

```bash
make run
```

You'll see the kernel boot sequence and two processes running cooperatively. Output shows:
- Kernel initialization
- Memory manager setup
- Process A creates file_a.txt
- Process B reads file_a.txt and creates file_b.txt
- File listings with correct byte counts

No user input needed—the system demonstrates all features automatically.

### Step 5: Exit QEMU

Press: `Ctrl+A`, then release, then press `X`

Alternative: `Ctrl+C` in the terminal to force quit

## File Descriptions

- `boot.S` - Assembly code: CPU startup, trap handling, context switching
- `kernel.c` - Main kernel: drivers, memory, processes, filesystem, syscalls
- `kernel.ld` - Linker script: memory layout and symbol definitions
- `common.h` - Header file: type definitions, CSR macros, syscall interface
- `makefile` - Build automation
- `setup-lab.sh` - Automated installation script
- `readme.md` - Full documentation

## Troubleshooting

### Compiler Not Found
```bash
# Try alternative compiler
sudo apt install gcc-riscv64-linux-gnu
# Edit makefile to use: riscv64-linux-gnu-gcc
```

### QEMU Not Found
```bash
sudo apt install qemu-system-misc
# Or: sudo apt install qemu-system (for all architectures)
```

### Make Not Found
```bash
sudo apt install build-essential
```

### Compilation Warnings
These warnings are expected and can be safely ignored:
- `implicit declaration of function 'fs_open'`
- `implicit declaration of function 'yield'`
- etc.

The code compiles and runs correctly despite them.

### QEMU Hangs or Loops
This is normal. The system runs Process A and B in an infinite loop, alternating execution. To exit, use Ctrl+A then X.

## What This OS Demonstrates

✅ **Boot Sequence** - CPU startup, stack initialization, entry to kernel_main()

✅ **Trap Handling** - Exception handling, interrupt routing, ecall dispatch

✅ **Memory Management** - Page allocator with linked-list free list, O(1) allocation

✅ **Cooperative Multitasking** - Process context switching, callee-saved register management

✅ **System Calls** - User/kernel transition via ecall, syscall dispatch mechanism

✅ **File System** - Inode-based RAM filesystem, 16 concurrent files, inter-process sharing

## Understanding the Code

The code is heavily commented. Start with:
1. `boot.S` - Understand the entry point
2. `kernel.c` main() - See initialization sequence
3. `kernel.c` trap_handler() - See exception handling
4. `kernel.c` process_a/process_b() - See process execution and syscalls

## Next Steps

1. **Modify a syscall** - Add a new system call ID and handler
2. **Add debug output** - Add printf() statements to understand execution flow
3. **Change process behavior** - Modify process_a() or process_b() to do something different
4. **Analyze memory usage** - Print free_pages before and after allocations

## References

- RISC-V Specification: https://riscv.org/technical/specifications/
- QEMU RISC-V: https://wiki.qemu.org/Documentation/Platforms/RISC-V
- RISC-V ABI: https://github.com/riscv-non-isa/riscv-abi-spec
