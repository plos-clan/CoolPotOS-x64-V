module idt

import cpu
import log
import driver.mouse
import driver.ps2
import driver.term

@[irq_handler]
fn devide_by_zero(frame &InterruptFrame) {
	log.error(c'Divide by zero!')
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn invalid_opcode(frame &InterruptFrame) {
	log.error(c'Invalid opcode!')
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn double_fault(frame &InterruptFrame, error_code u64) {
	log.error(c'Double fault (error code: %#llx)', error_code)
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn segment_not_present(frame &InterruptFrame, error_code u64) {
	log.error(c'Segment not present (error code: %#llx)', error_code)
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn general_protection_fault(frame &InterruptFrame, error_code u64) {
	log.error(c'General protection fault (error code: %#llx)', error_code)
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn page_fault(frame &InterruptFrame, error_code u64) {
	log.error(c'Page fault (error code: %#llx)', error_code)
	log.error(c'Faulting address: %#p', cpu.read_cr2())
	frame.debug()
	cpu.hlt()
}

@[irq_handler]
fn timer_handler(frame &InterruptFrame) {
	term.update()
	lapic.eoi()
}

@[irq_handler]
fn hpet_timer_handler(frame &InterruptFrame) {
	log.debug(c'Hpet Timer interrupt!')
	lapic.eoi()
}

@[irq_handler]
fn keyboard_handler(frame &InterruptFrame) {
	scancode := ps2.read_data() or { return }
	ksc_queue.push(scancode)
	defer { lapic.eoi() }
}

@[irq_handler]
fn mouse_handler(frame &InterruptFrame) {
	packet := ps2.read_data() or { return }
	mouse.process_packet(packet)
	lapic.eoi()
}
