#include "krlibc.h"

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

size_t strlen(const char *str) {
    const char *s = str;
    while (*s) {
        s++;
    }
    return s - str;
}

char* strcat(char* dest, const char* src) {
    char* ret = dest;
    while (*dest) dest++;
    while ((*dest++ = *src++));
    return ret;
}
