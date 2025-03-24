module idt

import cpu
import log
import driver.term

@[irq_handler]
fn devide_by_zero(frame &InterruptFrame) {
	log.error(c'Divide by zero!\n')
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn invalid_opcode(frame &InterruptFrame) {
	log.error(c'Invalid opcode!\n')
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn double_fault(frame &InterruptFrame, error_code u64) {
	log.error(c'Double fault (error code: %#llx)\n', error_code)
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn segment_not_present(frame &InterruptFrame, error_code u64) {
	log.error(c'Segment not present (error code: %#llx)\n', error_code)
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn general_protection_fault(frame &InterruptFrame, error_code u64) {
	log.error(c'General protection fault (error code: %#llx)\n', error_code)
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn page_fault(frame &InterruptFrame, error_code u64) {
	log.error(c'Page fault (error code: %#llx)\n', error_code)
	log.error(c'Faulting address: %#p\n', cpu.read_cr2())
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn timer(frame &InterruptFrame) {
	term.update()
	lapic.eoi()
}

@[irq_handler]
fn keyboard(frame &InterruptFrame) {
	scancode := cpu.port_in[u8](0x60)
	ksc_queue.push(scancode)
	lapic.eoi()
}

@[irq_handler]
fn mouse(frame &InterruptFrame) {
	log.debug(c'Mouse interrupt!\n')
	lapic.eoi()
}

@[irq_handler]
fn hpet_timer(frame &InterruptFrame) {
	log.debug(c'Hpet Timer interrupt!\n')
	lapic.eoi()
}
