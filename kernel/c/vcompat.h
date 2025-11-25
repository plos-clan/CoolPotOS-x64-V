#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define VV_EXP extern
#define VV_LOC static
#define E_STRUCT 0
#define E_STRUCT_DECL unsigned char _padding
#define VNORETURN __attribute__((noreturn))
#define __IRQHANDLER __attribute__((interrupt))
#define VUNREACHABLE() do { __builtin_unreachable(); } while (0)

#if defined(__x86_64__) || defined(_M_AMD64)
	#define __V_amd64  1
#endif
#if defined(__loongarch64)
	#define __V_loongarch64  1
#endif

typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;
typedef size_t usize;
typedef ptrdiff_t isize;
typedef u8 byte;
typedef void* voidptr;

bool _us64_gt(uint64_t a, int64_t b) {
    return a > INT64_MAX || (int64_t)a > b;
}

typedef struct {} IError;

const IError _const_none__;

typedef struct _option {
	u8 state;
	IError err;
} _option;

void builtin___option_ok(void* data, _option* option, int size) {
    option->state = 0;
    memcpy(((u8*)(&option->err)) + sizeof(IError), data, size);
}
