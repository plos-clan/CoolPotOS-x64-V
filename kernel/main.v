module main

import limine
import mem
import arch.cpu
import arch.gdt
import arch.idt
import driver.gop
import driver.serial
import driver.term

@[_linker_section: '.requests']
@[cinit]
__global (
	volatile base_revision = limine.BaseRevision{
		revision: 3
	}
)

pub fn main() {
	if base_revision.revision != 0 {
		for {}
	}

	gop.init()
	serial.init()

	mem.init_hhdm()
	mem.init_frame()
	mem.init_heap()

	term.init()
	gdt.init()
	idt.init()

	for {
		cpu.hlt()
	}
}
