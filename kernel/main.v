@[has_globals]
module main

import limine
import driver.acpi
import driver.display
import driver.pcie
import driver.serial as _
import driver.term
import driver.usb
import mem

$if amd64 {
	import arch.amd64.cpu
	import arch.amd64.gdt
	import arch.amd64.idt
	import arch.amd64.apic
	import arch.amd64.hpet
} $else {
	import arch.loongarch64.cpu
	import arch.loongarch64.trap
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

	mem.init_hhdm()
	mem.init_frame()
	mem.init_paging()
	mem.init_heap()

	acpi.init()
	serial.init()

	$if amd64 {
		gdt.init()
		idt.init()
	} $else {
		trap.init()
	}

	display.init()
	term.init()

	$if amd64 {
		hpet.init()
		apic.init()
		cpu.sti()
	}

	pcie.init()
	usb.init()

	for {
		xhci_temp.poll()
		cpu.hcf()
	}
}
