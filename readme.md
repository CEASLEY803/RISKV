# RISC-V SimpleOS

A minimal operating system for RISC-V that demonstrates bootloader, trap handling, multitasking, system calls, and a file system.

## Quick Start

### Install Tools (Personal Machine or WSL)
```bash
sudo apt update
sudo apt install -y gcc-riscv64-unknown-elf qemu-system-misc make
```

### Build & Run
```bash
cd myos
make
make run
```

### Exit QEMU
Press `Ctrl+A`, then `X`

## What It Does

When you run it, you'll see:
- **Boot messages** - OS initializing
- **Process A** - Creates a file, writes data, yields to Process B
- **Process B** - Reads the file created by A, creates its own file, yields back
- **Loop continues** - Alternates between processes forever

This demonstrates:
- Two concurrent processes
- Context switching (yielding)
- File creation and sharing between processes
- System calls (print, yield, file operations)

## Features

| Feature | Status |
|---------|--------|
| Boot sequence | ✅ |
| Trap handling (exceptions) | ✅ |
| System calls (8 total) | ✅ |
| Memory allocator | ✅ |
| Context switching | ✅ |
| Cooperative multitasking | ✅ |
| File system (16 files) | ✅ |
| Inter-process file sharing | ✅ |

## System Calls Implemented

1. `SYS_PUTS` - Print string
2. `SYS_YIELD` - Yield to next process
3. `SYS_OPEN` - Create/open file
4. `SYS_CLOSE` - Close file
5. `SYS_READ` - Read from file
6. `SYS_WRITE` - Write to file
7. `SYS_UNLINK` - Delete file
8. `SYS_LIST` - List all files

## Files

- `boot.S` - Assembly: CPU startup, trap handler, context switching
- `kernel.c` - C code: kernel, syscalls, filesystem, memory management
- `common.h` - Header: types, macros, syscall IDs
- `kernel.ld` - Linker script: memory layout
- `makefile` - Build rules

## Lab Machine Note

Lab machines don't have RISC-V tools installed. Options:
1. **Compile on personal machine** (recommended) - 5 minutes
2. **Build toolchain on lab machine** - 1-2 hours, no sudo needed
3. **Request IT install packages**

## Want to Understand the Code?

Read **CODE_WALKTHROUGH.md** - it explains all 7 components with diagrams and code examples.
