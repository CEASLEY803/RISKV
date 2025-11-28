OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
/* QEMU virt machine RAM starts at 0x80000000 */
. = 0x80000000;

.text : {
/* Ensure the text segment starts with the code from boot.S */
*(.text.boot)
*(.text .text.*)
}

.rodata : {
. = ALIGN(16);
*(.rodata .rodata.*)
}

.data : {
. = ALIGN(16);
*(.data .data.*)
}

.bss : {
. = ALIGN(16);
__bss_start = .;
*(.bss .bss.*)
*(.sbss .sbss.*)
__bss_end = .;
}

/* Provide a symbol for the end of the kernel image */
. = ALIGN(4096);
__kernel_end = .;
}