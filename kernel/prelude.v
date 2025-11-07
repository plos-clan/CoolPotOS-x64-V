module prelude

#include "krlibc.h"
#include "vcompat.h"

fn C.memset(voidptr, isize, usize)
fn C.memcmp(voidptr, voidptr, usize) int
