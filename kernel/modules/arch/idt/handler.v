module idt

import cpu
import log

fn devide_by_zero() {
	log.error(c"Divide by zero exception!\n")
	cpu.hlt()
}

fn invalid_opcode() {
	log.error(c"Invalid opcode!\n")
	cpu.hlt()
}

fn double_fault() {
	log.error(c"Double fault!\n")
	cpu.hlt()
}

fn segment_not_present() {
	log.error(c"Segment not present!\n")
	cpu.hlt()
}

fn general_protection_fault() {
	log.error(c"General protection fault!\n")
	cpu.hlt()
}

fn page_fault() {
	log.error(c"Page fault!\n")
	log.error(c"Faulting address: %#p\n", voidptr(cpu.read_cr2()))
	cpu.hlt()
}
