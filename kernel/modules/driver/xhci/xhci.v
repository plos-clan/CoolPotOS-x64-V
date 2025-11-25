module xhci

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

import log

pub struct Xhci {
pub mut:
	cap Capability
	op  Operational
}

pub fn Xhci.new(base_addr usize) Xhci {
	cap := Capability.new(base_addr)

	op_base := usize(base_addr) + cap.length()
	op := Operational.new(op_base)

	return Xhci{
		cap: cap
		op:  op
	}
}

fn (x Xhci) wait_ready() bool {
	for i := 0; i < 1_000_000; i++ {
		if !x.op.not_ready() {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

fn (x Xhci) wait_halted(expect_halted bool) bool {
	for i := 0; i < 1_000_000; i++ {
		if x.op.is_halted() == expect_halted {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

fn (x Xhci) wait_reset_complete() bool {
	for i := 0; i < 1_000_000; i++ {
		if (x.op.read_usbcmd() & 2) == 0 {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

fn (x Xhci) reset_controller() bool {
	log.debug(c'Resetting xHCI controller')

	if x.op.is_running() {
		log.debug(c'Controller is running, stopping')
		x.op.stop()

		if !x.wait_halted(true) {
			log.error(c'Failed to stop controller')
			return false
		}
	}

	x.op.reset()

	if !x.wait_reset_complete() {
		log.error(c'Reset timeout')
		return false
	}

	if !x.wait_ready() {
		log.error(c'Controller stuck in not ready state')
		return false
	}

	log.debug(c'xHCI controller reset complete')
	return true
}
