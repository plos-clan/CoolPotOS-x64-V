module term

// import mem.heap as _

fn C.heap_init(address &u8, size usize) bool
fn C.malloc(size usize) voidptr
fn C.free(voidptr)

__global (
	term_init = false
)

pub fn init() {
	display := C.TerminalDisplay{
		width:   framebuffer.width
		height:  framebuffer.height
		address: framebuffer.address
	}

	C.terminal_init(&display, 10.0, C.malloc, C.free, 0)
	term_init = true
}

pub fn process(s &char) {
	C.terminal_process(s)
}
