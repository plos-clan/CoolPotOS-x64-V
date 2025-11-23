@[has_globals]
module main

import limine
import driver.acpi
import driver.gop
import driver.serial
import driver.term
import mem

$if amd64 {
	import arch.amd64.cpu
	import arch.amd64.gdt
	import arch.amd64.idt
	import arch.amd64.apic
	import driver.hpet
	import driver.mouse
} $else {
	import arch.loongarch64.cpu
	import arch.loongarch64.int
}

@[_linker_section: '.limine_requests']
@[cinit]
__global (
	volatile base_revision = limine.BaseRevision{
		revision: 4
	}
)

pub fn main() {
	if base_revision.revision != 0 {
		for {}
	}

	$if amd64 {
		gdt.init()
		idt.init()
	} $else {
		int.init()
	}

	mem.init_hhdm()
	mem.init_frame()
	mem.init_paging()
	mem.init_heap()

	gop.init()
	serial.init()

	term.init()
	acpi.init()

	$if amd64 {
		hpet.init()
		apic.init()
		mouse.init()
		cpu.sti()
	}

	for {
		cpu.hcf()
	}
}
