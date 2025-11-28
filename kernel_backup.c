#include "common.h"

// QEMU virt machine UART0 base address
#define UART0_BASE 0x10000000

// We cast the address to a pointer so we can write to it.
// 'volatile' tells the compiler: "Do not optimize this! The value changes outside code control."
#define UART0_DR ((volatile uint8_t *)UART0_BASE)

void putchar(char c) {
    *UART0_DR = c;
}

void puts(const char *s) {
    while (*s) {
        putchar(*s++);
    }
}

/**
 * printf - A minimal printf implementation for bare metal
 * Supports: %s (string), %d (decimal), %x (hex), %% (literal %)
 *
 * Uses va_list macros to properly handle variadic arguments
 * across different calling conventions (RISC-V uses registers)
 */
void printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    while (*fmt) {
        if (*fmt == '%') {
            fmt++;
            switch (*fmt) {
                case 's': {
                    // String argument
                    const char *str = va_arg(args, const char *);
                    if (str == NULL) {
                        puts("(null)");
                    } else {
                        while (*str) {
                            putchar(*str++);
                        }
                    }
                    break;
                }
                case 'd': {
                    // Decimal integer
                    int64_t num = va_arg(args, int64_t);
                    if (num == 0) {
                        putchar('0');
                    } else {
                        // Handle negative numbers
                        if (num < 0) {
                            putchar('-');
                            num = -num;
                        }
                        // Convert to string and print
                        char digits[20];
                        int len = 0;
                        while (num > 0) {
                            digits[len++] = '0' + (num % 10);
                            num /= 10;
                        }
                        // Print in reverse order
                        while (len > 0) {
                            putchar(digits[--len]);
                        }
                    }
                    break;
                }
                case 'x': {
                    // Hexadecimal (8 digits, zero-padded)
                    uint64_t num = va_arg(args, uint64_t);
                    char hex[16] = "0123456789abcdef";
                    // Print 8 hex digits (32-bit value)
                    for (int i = 7; i >= 0; i--) {
                        putchar(hex[(num >> (i * 4)) & 0xF]);
                    }
                    break;
                }
                case '%': {
                    // Literal percent sign
                    putchar('%');
                    break;
                }
                default: {
                    // Unknown format specifier, just print it
                    putchar('%');
                    putchar(*fmt);
                    break;
                }
            }
            fmt++;
        } else {
            putchar(*fmt++);
        }
    }

    va_end(args);
}

/**
 * panic - Halt the system with an error message
 * This is called when an unrecoverable error occurs
 */
void panic(const char *msg) {
    puts("\n!!! KERNEL PANIC !!!\n");
    puts(msg);
    puts("\n");
    while (1) {
        __asm__ __volatile__("wfi");
    }
}

/**
 * Clear the .bss section (uninitialized data)
 * This ensures all global variables are zero-initialized
 */
extern uint8_t __bss_start, __bss_end;

void clear_bss(void) {
    uint8_t *bss = &__bss_start;
    while (bss < &__bss_end) {
        *bss++ = 0;
    }
}

/**
 * trap_init - Initialize trap handling
 * Sets up the trap vector address in the mtvec (Machine Trap Vector) CSR
 * Note: QEMU starts in machine mode, so we use mtvec not stvec
 */
void trap_init(void) {
    // Write the address of trap_vector to mtvec
    // mtvec[1:0] = 00 means "Direct" mode (jump to address)
    // mtvec[63:2] = base address of trap vector
    extern void trap_vector(void);
    write_csr(mtvec, (uint64_t)trap_vector);
    printf("Trap handler initialized at %x\n", (uint64_t)trap_vector);
}

/**
 * trap_handler - Handle a trap (interrupt or exception)
 * Called by assembly trap_vector when a trap occurs
 * @frame: Pointer to saved CPU state
 */
void trap_handler(TrapFrame *frame) {
    // Read the cause of the trap (machine mode)
    uint64_t cause = read_csr(mcause);
    uint64_t epc = read_csr(mepc);
    uint64_t tval = read_csr(mtval);

    // Decode the cause
    // Bit 63: 1 = Interrupt, 0 = Exception
    // Bits 62-0: Trap code
    uint64_t is_interrupt = (cause >> 63) & 1;
    uint64_t code = cause & 0x3F;

    if (is_interrupt) {
        printf("[INTERRUPT] Code: %d, EPC: %x\n", code, epc);
    } else {
        printf("[EXCEPTION] Code: %d, EPC: %x, TVAL: %x\n", code, epc, tval);

        // Decode common exception codes
        switch (code) {
            case 0:
                printf("  -> Instruction Address Misaligned\n");
                break;
            case 1:
                printf("  -> Instruction Access Fault\n");
                break;
            case 2:
                printf("  -> Illegal Instruction\n");
                break;
            case 3:
                printf("  -> Breakpoint (ebreak)\n");
                break;
            case 4:
                printf("  -> Load Address Misaligned\n");
                break;
            case 5:
                printf("  -> Load Access Fault\n");
                break;
            case 6:
                printf("  -> Store/AMO Address Misaligned\n");
                break;
            case 7:
                printf("  -> Store/AMO Access Fault\n");
                break;
            case 8:
                printf("  -> Environment Call (ecall from U-mode)\n");
                break;
            case 9:
                printf("  -> Environment Call (ecall from S-mode)\n");
                break;
            case 11:
                printf("  -> Environment Call (ecall from M-mode)\n");
                break;
            case 12:
                printf("  -> Instruction Page Fault\n");
                break;
            case 13:
                printf("  -> Load Page Fault\n");
                break;
            case 15:
                printf("  -> Store/AMO Page Fault\n");
                break;
            default:
                printf("  -> Unknown exception\n");
        }
    }

    // For recoverable exceptions, advance mepc past the exception-causing instruction
    // Most exceptions (like ecall) are 4 bytes, so increment by 4
    if (!is_interrupt) {
        if (code == 3) {  // Breakpoint - don't advance mepc
            // User may want to step past breakpoint, leave mepc as-is
        } else {
            // For other exceptions (ecall, etc), skip the instruction
            uint64_t new_epc = epc + 4;
            write_csr(mepc, new_epc);
            asm volatile("fence");
        }
    }

    // If it's an unrecoverable exception, panic
    // Allow breakpoints (code 3) and ecalls (code 8, 9, 11) to be recoverable
    if (!is_interrupt && code != 3 && code != 8 && code != 9 && code != 11) {
        panic("Unrecoverable exception!");
    }
}

// ============================================================================
// Memory Management - Page Allocator
// ============================================================================

#define PAGE_SIZE 4096
#define KERNEL_BASE 0x80000000
#define RAM_SIZE (128 * 1024 * 1024)  // 128MB (QEMU default)

/**
 * Page structure - Each free page acts as a linked list node.
 * We store the "next" pointer in the first 8 bytes of each page.
 */
typedef struct page {
    struct page *next;
} Page;

/**
 * Global page allocator state
 */
static Page *free_page_list = NULL;
static uint64_t total_pages = 0;
static uint64_t free_pages = 0;

/**
 * pages_init - Initialize the page allocator
 * Sets up a linked list of all free pages in RAM
 */
void pages_init(void) {
    // Calculate the end of the kernel image
    extern uint8_t __kernel_end;
    uint64_t kernel_end = (uint64_t)&__kernel_end;

    // Align kernel_end up to the next page boundary
    uint64_t free_mem_start = align_up(kernel_end, PAGE_SIZE);

    // Calculate total available memory
    uint64_t ram_end = KERNEL_BASE + RAM_SIZE;
    total_pages = (ram_end - free_mem_start) / PAGE_SIZE;
    free_pages = total_pages;

    printf("\n--- Memory Manager Initialized ---\n");
    printf("Kernel end:    0x%x\n", kernel_end);
    printf("Free mem:      0x%x\n", free_mem_start);
    printf("RAM end:       0x%x\n", ram_end);
    printf("Total pages:   %d KB\n", total_pages);

    // Build the linked list of free pages
    // Start from the first free page and link them all together
    Page *current = (Page *)free_mem_start;
    free_page_list = current;

    for (uint64_t i = 0; i < total_pages - 1; i++) {
        Page *next = (Page *)((uint64_t)current + PAGE_SIZE);
        current->next = next;
        current = next;
    }

    // Last page has no next
    current->next = NULL;
}

/**
 * alloc_page - Allocate a single 4KB page
 * Returns the physical address of the allocated page, or 0 on failure
 */
uint64_t alloc_page(void) {
    if (free_page_list == NULL) {
        printf("ERROR: Out of memory! No free pages.\n");
        return 0;
    }

    Page *page = free_page_list;
    free_page_list = page->next;
    free_pages--;

    // Zero-fill the page
    uint8_t *p = (uint8_t *)page;
    for (int i = 0; i < PAGE_SIZE; i++) {
        p[i] = 0;
    }

    return (uint64_t)page;
}

/**
 * free_page - Return a page to the free list
 * Takes the physical address of the page to free
 */
void free_page(uint64_t page_addr) {
    if (page_addr == 0) {
        printf("ERROR: Attempted to free NULL page.\n");
        return;
    }

    Page *page = (Page *)page_addr;
    page->next = free_page_list;
    free_page_list = page;
    free_pages++;
}

/**
 * alloc_pages - Allocate multiple contiguous pages
 * Note: This is a simple implementation that returns individual pages.
 * For true contiguous allocation, a more sophisticated allocator is needed.
 */
uint64_t alloc_pages(uint64_t count) {
    if (count == 1) {
        return alloc_page();
    }

    // For now, just allocate the first page and warn
    printf("WARNING: alloc_pages(%d) requested, but returning only 1 page.\n", count);
    return alloc_page();
}

/**
 * mem_test - Simple test to verify page allocator is working
 */
void mem_test(void) {
    printf("\n--- Testing Page Allocator ---\n");

    // Allocate a page
    uint64_t page1 = alloc_page();
    if (page1 == 0) {
        printf("FAIL: Could not allocate first page\n");
        return;
    }
    printf("Allocated page 1: 0x%x\n", page1);
    printf("Free pages now: %d\n", free_pages);

    // Write a test value
    uint64_t *test_ptr = (uint64_t *)page1;
    *test_ptr = 0xDEADBEEF;

    // Allocate another page
    uint64_t page2 = alloc_page();
    if (page2 == 0) {
        printf("FAIL: Could not allocate second page\n");
        return;
    }
    printf("Allocated page 2: 0x%x\n", page2);
    printf("Free pages now: %d\n", free_pages);

    // Verify first page still has our value
    if (*test_ptr == 0xDEADBEEF) {
        printf("PASS: Page 1 still contains our test value\n");
    } else {
        printf("FAIL: Page 1 value was corrupted\n");
    }

    // Free the pages
    free_page(page2);
    printf("Freed page 2, free pages now: %d\n", free_pages);

    free_page(page1);
    printf("Freed page 1, free pages now: %d\n", free_pages);
}

void kernel_main(void) {
    // Clear BSS section (zero-initialize global variables)
    clear_bss();

    printf("\n");
    printf("================================\n");
    printf("RISC-V SimpleOS - Boot Sequence\n");
    printf("================================\n");
    printf("Kernel loaded at address: 0x%x\n", 0x80000000);
    printf("Test Math: 10 + 20 = %d\n", 10 + 20);
    printf("Test Hex:  255 = 0x%x\n", 255);

    printf("\n[1] Initializing trap handling...\n");
    trap_init();
    printf("    Trap handling enabled.\n");

    printf("\n[2] Initializing memory manager...\n");
    pages_init();

    printf("\n[3] Testing memory allocator...\n");
    mem_test();

    printf("\n[4] Testing trap handling with ecall...\n");
    __asm__ __volatile__("ecall");
    printf("    Exception handled successfully!\n");

    printf("\n================================\n");
    printf("Boot complete. Kernel ready.\n");
    printf("================================\n");

    // Infinite loop to stop execution from falling off the edge
    while (1) {
        // Wait for interrupt (power saving)
        __asm__ __volatile__("wfi");
    }
}