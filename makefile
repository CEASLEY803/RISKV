# Try to auto-detect the RISC-V compiler prefix
# Common prefixes: riscv64-unknown-elf-, riscv64-linux-gnu-
CC = $(shell which riscv64-unknown-elf-gcc >/dev/null 2>&1 && echo riscv64-unknown-elf-gcc || echo riscv64-linux-gnu-gcc)
OBJCOPY = $(shell which riscv64-unknown-elf-objcopy >/dev/null 2>&1 && echo riscv64-unknown-elf-objcopy || echo riscv64-linux-gnu-objcopy)

# Compiler Flags
# -nostdlib: Don't link standard libraries (we are the OS!)
# -mcmodel=medany: Standard memory model for RISC-V kernels
# -g: Include debug info
CFLAGS = -Wall -Wextra -O2 -g -mcmodel=medany -ffreestanding -nostdlib

# Source files
SRCS = kernel.c boot.S
OBJS = $(SRCS:.c=.o)
OBJS := $(OBJS:.S=.o)

# QEMU Flags
# -machine virt: The standard generic RISC-V board
# -bios none: We are providing the boot code, don't load OpenSBI
# -nographic: Run in the terminal, not a GUI window
QEMU_FLAGS = -machine virt -bios none -nographic -serial mon:stdio --no-reboot

all: kernel.elf

kernel.elf: kernel.ld $(OBJS)
	$(CC) -T kernel.ld -o $@ $(CFLAGS) $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@

run: kernel.elf
	qemu-system-riscv64 $(QEMU_FLAGS) -kernel kernel.elf

clean:
	rm -f *.o *.elf

.PHONY: all run clean