module mem

#include "alloc.h"

fn C.heap_init(address &u8, size usize) bool

pub fn init_heap() {
	C.heap_init(&u8(physical_memory_offset + 0x100000), 0x400000)
}
