#include <stdint.h>
#include <stddef.h>

void* memcpy(void* dst, const void* src, size_t n) {
    uint8_t* d = dst;
    const uint8_t* s = src;
    while(n--) *d++ = *s++;
    return dst;
}

void* memset(void* dst, int val, size_t n) {
    uint8_t* d = dst;
    while(n--) *d++ = val;
    return dst;
}

int memcmp(const void* s1, const void* s2, size_t n) {
    const uint8_t* p1 = s1;
    const uint8_t* p2 = s2;
    while(n--) {
        if(*p1 != *p2) return *p1 - *p2;
        p1++;
        p2++;
    }
    return 0;
}
