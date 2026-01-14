module term

#define TERMINAL_EMBEDDED_FONT
#include "os_terminal.h"

@[typedef]
struct C.TerminalDisplay {
	width            usize
	height           usize
	buffer           &u32
	pitch            usize
	red_mask_size    u8
	red_mask_shift   u8
	green_mask_size  u8
	green_mask_shift u8
	blue_mask_size   u8
	blue_mask_shift  u8
}

fn C.terminal_new(&C.TerminalDisplay, f32, fn (usize), fn (voidptr)) voidptr
fn C.terminal_flush(voidptr)
fn C.terminal_process_byte(voidptr, char)
fn C.terminal_handle_keyboard(voidptr, u8)
fn C.terminal_handle_mouse_scroll(voidptr, isize)
fn C.terminal_set_scroll_speed(voidptr, usize)
fn C.terminal_set_auto_flush(voidptr, bool)
fn C.terminal_set_crnl_mapping(voidptr, bool)
fn C.terminal_set_pty_writer(voidptr, fn (&u8, usize))
