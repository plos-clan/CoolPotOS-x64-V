#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum HeapError {
  InvalidFree,
  LayoutError,
} HeapError;

typedef void (*ErrorHandler)(enum HeapError error, void *ptr);

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

bool heap_init(uint8_t *address, size_t size);
void heap_onerror(ErrorHandler handler);
size_t usable_size(void *ptr);
void *malloc(size_t size);
void *aligned_alloc(size_t alignment, size_t size);
void free(void *ptr);
void *realloc(void *ptr, size_t size);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus
