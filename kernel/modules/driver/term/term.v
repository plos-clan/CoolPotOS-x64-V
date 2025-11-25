@[has_globals]
module term

import utils { Queue }

__global (
	term_buffer Queue[char]
)

pub fn update() {
	mut need_flush := false

	for {
		ch := term_buffer.pop() or { break }
		C.terminal_process_byte(ch)
		need_flush = true
	}

	if need_flush {
		C.terminal_flush()
	}
}

fn pty_writer(buf &u8) {
	unsafe {
		for i := 0; buf[i]; i++ {
			term_buffer.push(buf[i])
		}
	}
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

	C.terminal_init(&display, 10.0, C.malloc, C.free)
	C.terminal_set_auto_flush(false)
	C.terminal_set_crnl_mapping(true)
	C.terminal_set_scroll_speed(5)
	C.terminal_set_pty_writer(pty_writer)

	term_buffer = Queue.new[char](4096)
}
