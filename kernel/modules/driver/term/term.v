module term

import beep
import sync { Queue }

__global (
	ksc_queue   Queue[u8]
	term_buffer Queue[char]
)

pub fn update() {
	for {
		sc := ksc_queue.pop() or { break }
		handle_keyboard(sc)
	}

	mut need_flush := false

	for {
		ch := term_buffer.pop() or { break }
		C.terminal_process_char(ch)
		need_flush = true
	}

	if need_flush {
		C.terminal_flush()
	}
}

pub fn init() {
	width := framebuffer.width
	height := framebuffer.height
	address := framebuffer.address

	display := C.TerminalDisplay{width, height, address}
	C.terminal_init(&display, 10.0, C.malloc, C.free, 0)
	C.terminal_set_auto_crnl(true)
	C.terminal_set_auto_flush(false)
	C.terminal_set_bell_handler(fn () {beep.play(750, 100)})

	ksc_queue = sync.Queue.new[u8](1024)
	term_buffer = sync.Queue.new[char](1024)
}
