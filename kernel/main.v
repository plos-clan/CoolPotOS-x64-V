@[has_globals]
module main

import arch.acpi
import arch.apic
import arch.cpu
import arch.gdt
import arch.idt
import driver.gop
import driver.hpet
import driver.mouse
import driver.serial
import driver.term
import limine
import mem

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
	gdt.init()
	idt.init()

	mem.init_hhdm()
	mem.init_frame()
	mem.init_paging()
	mem.init_heap()

	term.init()
	acpi.init()
	hpet.init()
	apic.init()
	mouse.init()

	for {
		cpu.hlt()
	}
}
