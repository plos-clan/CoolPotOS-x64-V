module core

import bus
import regs
import log

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub struct Xhci implements bus.HostController {
pub mut:
	cap        regs.Capability
	op         regs.Operational
	ctx_size   int
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
	xhci.ctx_size = if xhci.cap.context_64byte() { 64 } else { 32 }

	return xhci
}

pub fn (mut self Xhci) poll() {
	mut need_update := false
	for _ in 0 .. 16 {
		evt := self.event_ring.pop() or { break }
		self.handle_one_event(evt)
		need_update = true
	}
	if need_update {
		self.event_ring.update_erdp()
	}
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

fn (mut self Xhci) disable_slot(slot_id u8) {
	cmd := Trb.new_disable_slot(slot_id)

	self.send_command(cmd) or {
		log.error(c'Failed to disable slot: %d', slot_id)
		return
	}
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

		self.handle_one_event(evt)
	}
	return none
}

fn (mut self Xhci) handle_one_event(evt Trb) {
	match evt.get_type() {
		trb_transfer_event {
			slot_id := evt.slot_id()
			code := evt.completion_code()
			dci := evt.endpoint_id()
			len := evt.transfer_length()
			self.complete_transfer(slot_id, dci, code, len)
		}
		trb_port_status_change {
			port_id := evt.param_low >> 24
			log.info(c'Port %d status change', port_id)
			mut port := regs.Port.new(self.op.base_addr, int(port_id - 1))
			self.handle_port(port)
		}
		trb_cmd_completion {
			log.debug(c'Stale command completion ignored')
		}
		else {
			log.debug(c'Ignored event type %d', evt.get_type())
		}
	}
}
