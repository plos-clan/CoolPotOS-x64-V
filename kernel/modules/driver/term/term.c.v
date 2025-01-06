module term

#define TERMINAL_EMBEDDED_FONT
#include "os_terminal.h"

__global (
	term_init = false
)

@[typedef]
struct C.TerminalDisplay {
	width   usize
	height  usize
	address &u32
}

fn C.malloc(size usize) voidptr
fn C.free(voidptr)

fn C.terminal_init(&C.TerminalDisplay, f32, fn (usize) voidptr, fn (voidptr), voidptr)
fn C.terminal_process(s &char)

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
