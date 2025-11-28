#pragma once

// Unsigned integer types
typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;
typedef unsigned long long uint64_t;

// Signed integer types
typedef signed char int8_t;
typedef signed short int16_t;
typedef signed int int32_t;
typedef signed long long int64_t;

// Other types
typedef uint64_t size_t;
typedef uint64_t paddr_t; // Physical address
typedef uint64_t vaddr_t; // Virtual address

#define true  1
#define false 0
#define NULL  ((void *)0)

#define align_up(value, align)   (((value) + (align) - 1) / (align) * (align))
#define is_aligned(value, align) __builtin_is_aligned(value, align)
#define offsetof(type, member)   __builtin_offsetof(type, member)

// Variadic argument wrappers for printf
#define va_list  __builtin_va_list
#define va_start __builtin_va_start
#define va_end   __builtin_va_end
#define va_arg   __builtin_va_arg

// Control Status Register (CSR) macros
#define read_csr(reg)       ({ uint64_t __v; asm volatile("csrr %0, " #reg : "=r"(__v)); __v; })
#define write_csr(reg, val) asm volatile("csrw " #reg ", %0" : : "r"(val))
#define set_csr(reg, val)   asm volatile("csrs " #reg ", %0" : : "r"(val))
#define clr_csr(reg, val)   asm volatile("csrc " #reg ", %0" : : "r"(val))

// System Call Numbers
#define SYS_PUTS   1
#define SYS_YIELD  2
#define SYS_OPEN   3
#define SYS_CLOSE  4
#define SYS_READ   5
#define SYS_WRITE  6
#define SYS_UNLINK 7
#define SYS_LIST   8

// File operation constants
#define MAX_FILENAME 64
#define MAX_FILE_SIZE 4096  // 1 page
#define MAX_INODES 16
#define MAX_OPEN_FILES 8
#define MAX_PROCESSES 2

// Inline syscall function - executes ecall instruction
// Syscall convention:
// - a7 = syscall ID
// - a0 = first argument (also used for return value)
// - a1 = second argument
// - a2 = third argument
static inline uint64_t syscall(uint64_t id, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret;
    asm volatile(
        "mv a7, %1\n"      // Move syscall ID to a7
        "mv a0, %2\n"      // Move arg0 to a0
        "mv a1, %3\n"      // Move arg1 to a1
        "mv a2, %4\n"      // Move arg2 to a2
        "ecall\n"          // Execute syscall (trap to kernel)
        "mv %0, a0\n"      // Move return value from a0
        : "=r" (ret)
        : "r" (id), "r" (arg0), "r" (arg1), "r" (arg2)
        : "a0", "a1", "a2", "a7"
    );
    return ret;
}

// Trap frame structure - matches register save order in trap_vector
typedef struct {
    uint64_t ra, sp, gp, tp, t0, t1, t2, s0, s1;
    uint64_t a0, a1, a2, a3, a4, a5, a6, a7;
    uint64_t s2, s3, s4, s5, s6, s7, s8, s9, s10, s11;
    uint64_t t3, t4, t5, t6;
} TrapFrame;

// Function declarations
void *memset(void *dst, int c, size_t n);
void *memcpy(void *dst, const void *src, size_t n);
char *strcpy(char *dst, const char *src);
int strcmp(const char *s1, const char *s2);
void printf(const char *fmt, ...);
void trap_init(void);
void trap_handler(TrapFrame *frame);

// System call interface
void sys_puts(const char *s);
void sys_yield(void);
int sys_open(const char *filename);
int sys_close(int fd);
int sys_read(int fd, char *buf, int count);
int sys_write(int fd, const char *buf, int count);
int sys_unlink(const char *filename);
void sys_list(void);

// Helper functions
size_t strlen(const char *s);