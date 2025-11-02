module term

#define TERMINAL_EMBEDDED_FONT
#include "os_terminal.h"

@[typedef]
struct C.TerminalDisplay {
	width   usize
	height  usize
	buffer  &u32
	pitch   usize
	red_mask_size   u8
	red_mask_shift  u8
	green_mask_size u8
	green_mask_shift u8
	blue_mask_size  u8
	blue_mask_shift u8
}

fn C.terminal_init(&C.TerminalDisplay, f32, fn (usize), fn (voidptr))
fn C.terminal_process_byte(char)
fn C.terminal_flush()
fn C.terminal_set_crnl_mapping(bool)
fn C.terminal_set_auto_flush(bool)
fn C.terminal_set_bell_handler(fn ())
fn C.terminal_handle_keyboard(scancode u8)
fn C.terminal_set_pty_writer(fn (&u8))
