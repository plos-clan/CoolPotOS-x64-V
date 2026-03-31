module core

import bus
import regs
import log
import utils { Oneshot }

pub struct Xhci implements bus.HostController {
pub mut:
	cap           regs.Capability
	op            regs.Operational
	ctx_size      int
	dcbaa_virt    &u64 = unsafe { nil }
	cmd_ring      CommandRing
	event_ring    EventRing
	doorbell      regs.Doorbell
	slots         [256]Slot
	pending_ports [256]bool
	cmd_chan       Oneshot[Trb]
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

pub fn (mut self Xhci) handle_irq() {
	mut need_update := false
	for _ in 0 .. 16 {
		evt := self.event_ring.pop() or { break }
		self.handle_one_event(evt)
		need_update = true
	}
	if need_update {
		self.event_ring.update_erdp()
	}

	max_ports := self.cap.max_ports()
	for i in 0 .. max_ports {
		if !self.pending_ports[i] {
			continue
		}
		self.pending_ports[i] = false
		log.info(c'Port %d status change', i + 1)
		mut port := regs.Port.new(self.op.base_addr, i)
		self.handle_port(port)
	}
}

pub fn (mut self Xhci) test_command_ring() ? {
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
	self.cmd_chan.reset()
	self.cmd_ring.enqueue(trb)
	self.doorbell.ring(0, 0)

	evt := self.cmd_chan.recv()
	return evt.completion_code(), evt.slot_id()
}

fn (mut self Xhci) handle_one_event(evt Trb) {
	match evt.get_type() {
		trb_transfer_event {
			slot_id := evt.slot_id()
			dci := evt.endpoint_id()
			if dci == 1 {
				self.slots[slot_id].ctrl_chan.send(evt)
			} else {
				code := evt.completion_code()
				len := evt.transfer_length()
				self.complete_transfer(slot_id, dci, code, len)
			}
		}
		trb_port_status_change {
			port_id := evt.param_low >> 24
			if port_id > 0 && port_id <= u32(self.cap.max_ports()) {
				self.pending_ports[port_id - 1] = true
			}
		}
		trb_cmd_completion {
			self.cmd_chan.send(evt)
		}
		else {
			log.debug(c'Ignored event type %d', evt.get_type())
		}
	}
}
