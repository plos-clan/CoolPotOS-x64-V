module term

#define TERMINAL_EMBEDDED_FONT
#include "os_terminal.h"

@[typedef]
struct C.TerminalDisplay {
	width   usize
	height  usize
	address &u32
}

fn C.terminal_init(&C.TerminalDisplay, f32, fn (usize) voidptr, fn (voidptr), voidptr)
fn C.terminal_process(s &char)
