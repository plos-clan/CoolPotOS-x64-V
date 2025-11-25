module core

import regs
import log

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
}

pub fn Xhci.new(base_addr usize) Xhci {
	cap := regs.Capability.new(base_addr)

	op_base := usize(base_addr) + cap.length()
	db_base := usize(base_addr) + cap.db_off()

	return Xhci{
		cap:      cap
		op:       regs.Operational.new(op_base)
		doorbell: regs.Doorbell.new(db_base)
	}
}

pub fn (mut self Xhci) test_command_ring() ? {
	log.info(c'Testing command ring with NO_OP')

	self.cmd_ring.enqueue(Trb.new_no_op_cmd())
	self.doorbell.ring(0, 0)

	for _ in 0 .. 1_000_000 {
		if !self.event_ring.has_event() {
			cpu.spin_hint()
			continue
		}

		evt := self.event_ring.pop() or { continue }
		self.event_ring.update_erdp()

		if evt.get_type() != trb_cmd_completion {
			log.debug(c'Ignored event type: %d', evt.get_type())
			continue
		}

		code := evt.completion_code()
		if code == 1 {
			log.success(c'xHCI command ring verified')
			return
		}

		log.error(c'NO_OP failed with code: %d', code)
		return
	}

	log.error(c'NO_OP test failed: timeout')
	return none
}
