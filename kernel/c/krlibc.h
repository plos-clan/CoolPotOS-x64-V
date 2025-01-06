#pragma once

#include <stddef.h>
#include <stdint.h>

void* memcpy(void* dst, const void* src, size_t n);

void* memset(void* dst, int val, size_t n);

size_t strlen(const char *str);

char* strcat(char* dest, const char* src);
