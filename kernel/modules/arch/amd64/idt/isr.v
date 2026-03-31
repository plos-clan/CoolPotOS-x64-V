module idt

import log

@[irq_handler]
fn irq_dispatcher(frame &InterruptFrame) {
	vector := lapic.current_vector() or {
		log.warn(c'Spurious interrupt received!')
		return
	}

	if mut handler := vector_allocator.handlers[vector] {
		handler.handle_irq()
	} else {
		log.warn(c'Unhandled IRQ on vector %#x', vector)
	}

	lapic.eoi()
}
