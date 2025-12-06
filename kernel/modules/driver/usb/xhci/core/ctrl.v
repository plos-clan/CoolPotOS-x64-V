module core

import log

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

fn (self &Xhci) wait_ready() bool {
	for _ in 0 .. 1_000_000 {
		if !self.op.not_ready() {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

fn (self &Xhci) wait_halted() bool {
	for _ in 0 .. 1_000_000 {
		if self.op.is_halted() {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

fn (self &Xhci) wait_reset_complete() bool {
	for _ in 0 .. 1_000_000 {
		if (self.op.read_usbcmd() & 2) == 0 {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

pub fn (self &Xhci) reset_controller() bool {
	log.debug(c'Resetting xHCI controller')

	if self.op.is_running() {
		log.debug(c'Controller is running, stopping')
		self.op.stop()

		if !self.wait_halted() {
			log.error(c'Failed to stop controller')
			return false
		}
	}

	self.op.reset()

	if !self.wait_reset_complete() {
		log.error(c'Reset timeout')
		return false
	}

	if !self.wait_ready() {
		log.error(c'Controller stuck in not ready state')
		return false
	}

	log.debug(c'xHCI controller reset complete')
	return true
}
