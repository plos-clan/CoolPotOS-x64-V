module term

#define TERMINAL_EMBEDDED_FONT
#include "os_terminal.h"

@[typedef]
struct C.TerminalDisplay {
	width   usize
	height  usize
	address &u32
}

fn C.terminal_init(&C.TerminalDisplay, f32, fn (usize), fn (voidptr), voidptr)
fn C.terminal_process_char(ch char)
fn C.terminal_flush()
fn C.terminal_set_auto_crnl(bool)
fn C.terminal_set_auto_flush(bool)
fn C.terminal_set_bell_handler(fn ())
fn C.terminal_handle_keyboard(scancode u8) &char

fn handle_keyboard(sc u8) {
	res := C.terminal_handle_keyboard(sc)
	unsafe {
		for i := 0; res != 0 && res[i] != 0; i++ {
			term_buffer.push(res[i])
		}
	}
}
