module core

import regs
import log
import mem

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub struct Xhci {
pub mut:
	cap        regs.Capability
	op         regs.Operational
	dcbaa_virt &u64 = unsafe { nil }
	cmd_ring   CommandRing
	event_ring EventRing
	doorbell   regs.Doorbell
	slots      [256]Slot
}

pub fn Xhci.new(base_addr usize) &Xhci {
	ptr := C.malloc(sizeof(Xhci))
	C.memset(ptr, 0, sizeof(Xhci))

	mut xhci := unsafe { &Xhci(ptr) }

	xhci.cap = regs.Capability.new(base_addr)
	op_base := usize(base_addr) + xhci.cap.length()
	db_base := usize(base_addr) + xhci.cap.db_off()

	xhci.op = regs.Operational.new(op_base)
	xhci.doorbell = regs.Doorbell.new(db_base)

	return xhci
}

pub fn (mut self Xhci) test_command_ring() ? {
	log.info(c'Testing command ring with no op')

	cmd := Trb.new_no_op_cmd()

	code, _ := self.send_command(cmd) or {
		log.error(c'No op command timeout or error')
		return none
	}

	if code == 1 {
		log.success(c'xHCI command ring verified')
	} else {
		log.error(c'No op failed with code: %d', code)
		return none
	}
}

fn (mut self Xhci) enable_slot() ?u8 {
	cmd := Trb.new_enable_slot()
	code, slot_id := self.send_command(cmd) or { return none }

	if code != 1 {
		log.error(c'Failed to enable slot: %d', code)
		return none
	}

	return slot_id
}

fn (mut self Xhci) send_command(trb Trb) ?(u32, u8) {
	self.cmd_ring.enqueue(trb)
	self.doorbell.ring(0, 0)

	evt := self.wait_event(trb_cmd_completion, none)?
	return evt.completion_code(), evt.slot_id()
}

fn (mut self Xhci) wait_event(@type u32, slot ?u8) ?Trb {
	for _ in 0 .. 1_000_000 {
		evt := self.event_ring.pop() or {
			cpu.spin_hint()
			continue
		}
		self.event_ring.update_erdp()

		is_type_match := evt.get_type() == @type
		is_slot_match := (slot or { evt.slot_id() } == evt.slot_id())

		if is_type_match && is_slot_match {
			return evt
		}

		self.handle_unexpected_event(evt)
	}
	return none
}

fn (mut self Xhci) handle_unexpected_event(evt Trb) {
	match evt.get_type() {
		trb_port_status_change {
			port_id := evt.param_low >> 24
			log.info(c'Hotplug port %d during wait', port_id)
		}
		trb_transfer_event {
			log.warn(c'Unhandled transfer for slot %d', evt.slot_id())
		}
		else {
			log.debug(c'Ignoring event type: %d', evt.get_type())
		}
	}
}
