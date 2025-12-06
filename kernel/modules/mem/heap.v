module mem

#include "alloc.h"

const heap_start = u64(0xffffc00000000000)
const heap_size = 8 * 1024 * 1024

fn C.heap_init(address &u8, size usize) bool
fn C.malloc(size usize) voidptr
fn C.free(voidptr)
fn C.realloc(ptr voidptr, size usize) voidptr

pub fn init_heap() {
	flags := MappingType.kernel_data.flags()
	kernel_page_table.alloc_range(heap_start, heap_size, flags)
	C.heap_init(&u8(heap_start), heap_size)
}
