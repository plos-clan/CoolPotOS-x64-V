@[has_globals]
module log

import sync { SpinLock }

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

#define STB_SPRINTF_NOFLOAT
#define STB_SPRINTF_IMPLEMENTATION
#include "sprintf.h"

@[typedef]
struct C.va_list {}

fn C.va_start(voidptr, voidptr)
fn C.va_end(voidptr)

fn C.strcat(&char, &char) &char
fn C.stbsp_vsnprintf(&char, usize, &char, C.va_list) int

__global (
	log_buf  [4096]u8
	log_lock SpinLock
)

pub fn vprint(fmt voidptr, ap C.va_list) {
	was_enabled := cpu.interrupt_state()
	cpu.cli()

	log_lock.lock()

	defer {
		log_lock.unlock()
		if was_enabled {
			cpu.sti()
		}
	}

	len := C.stbsp_vsnprintf(&log_buf[0], sizeof(log_buf), fmt, ap)

	mut final_len := usize(0)
	match true {
	    len <= 0 { return }
	    len > 4095 { final_len = 4095 }
	    else { final_len = usize(len) }
	}

	$if !prod {
		serial.write(&log_buf[0])
	}

	term_buffer.push_many(&log_buf[0], final_len)
}
