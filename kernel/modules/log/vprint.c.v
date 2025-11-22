module log

import driver.serial

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
	C.stbsp_vsnprintf(&buf[0], sizeof(buf), fmt, ap)

	$if !prod {
		serial.write(&buf[0])
	}

	// for i := 0; buf[i]; i++ {
	// 	term_buffer.push(buf[i])
	// }
}
