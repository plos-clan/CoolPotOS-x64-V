module log

#define STB_SPRINTF_NOFLOAT
#define STB_SPRINTF_IMPLEMENTATION
#include "sprintf.h"

@[typedef]
struct C.va_list {}

fn C.va_start(voidptr, voidptr)
fn C.va_end(voidptr)

fn C.strcat(&char, &char) &char
fn C.stbsp_vsnprintf(&char, usize, &char, C.va_list) int

pub fn vprint(fmt voidptr, ap C.va_list) {
	buf := [4096]u8{}
	len := C.stbsp_vsnprintf(&buf[0], sizeof(buf), fmt, ap)

	mut final_len := usize(0)
	match true {
	    len <= 0 { return }
	    len > 4095 { final_len = 4095 }
	    else { final_len = usize(len) }
	}

	$if !prod {
		serial.write(&buf[0])
	}

	term_buffer.push_many(&buf[0], final_len)
}
