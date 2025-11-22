#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#define _MOV
#define VV_LOC static
#define E_STRUCT 0
#define E_STRUCT_DECL unsigned char _padding
#define __IRQHANDLER __attribute__((interrupt))

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
typedef int64_t int_literal;
typedef void* voidptr;

bool _us64_gt(uint64_t a, int64_t b) {
    return a > INT64_MAX || (int64_t)a > b;
}

void* builtin__memdup(void* src, usize _size) {
    return src;
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

typedef struct array {
    int len;
    void* data;
} array;

array builtin__new_array_from_c_array(int len, int, int, void* arr) {
	return (array){.len = len, .data = arr};
}
