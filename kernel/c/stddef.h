#ifndef STDDEF_H
#define STDDEF_H 1

typedef unsigned int size_t;
typedef int ptrdiff_t;

#undef NULL
#define NULL ((void *)0)

#undef offsetof
#define offsetof(type, member) ((size_t) &((type *)0)->member)

#endif
