@[has_globals]
module idt

import utils { Bitmap }

pub interface IrqHandler {
mut:
	handle_irq()
}

struct VectorAllocator {
mut:
	bitmap   Bitmap
	buffer   [32]u8
	handlers [256]?IrqHandler
}

__global (
	vector_allocator VectorAllocator
)

fn (mut self VectorAllocator) init() {
	self.bitmap = Bitmap.init(&self.buffer[0], 32)
	self.bitmap.set_range(0, 32, true)
}

pub fn (mut self VectorAllocator) alloc(handler IrqHandler) ?u8 {
	index := self.bitmap.find_range(1, false)?
	self.bitmap.set(index, true)
	self.handlers[index] = handler
	return u8(index)
}
