@[has_globals]
module term

import utils { Queue }

__global (
	term_ptr    voidptr
	term_buffer Queue[char]
)

pub fn update() {
	mut need_flush := false

	for {
		ch := term_buffer.pop() or { break }
		C.terminal_process_byte(term_ptr, ch)
		need_flush = true
	}

	if need_flush {
		C.terminal_flush(term_ptr)
	}
}

fn pty_writer(buf &u8, size usize) {
	term_buffer.push_many(buf, u64(size))
}

pub fn init() {
	display := C.TerminalDisplay{
		framebuffer.width,
		framebuffer.height,
		framebuffer.address,
		framebuffer.pitch,
		framebuffer.red_mask_size,
		framebuffer.red_mask_shift,
		framebuffer.green_mask_size,
		framebuffer.green_mask_shift,
		framebuffer.blue_mask_size,
		framebuffer.blue_mask_shift,
	}

	term_ptr = C.terminal_new(&display, 10.0, C.malloc, C.free)
	C.terminal_set_auto_flush(term_ptr, false)
	C.terminal_set_crnl_mapping(term_ptr, true)
	C.terminal_set_scroll_speed(term_ptr, 5)
	C.terminal_set_pty_writer(term_ptr, pty_writer)

	term_buffer = Queue.new[char](4096)
}
