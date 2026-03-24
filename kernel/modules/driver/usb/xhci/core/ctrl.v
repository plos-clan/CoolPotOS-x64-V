module core

import log
import regs { LegacySupport }

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

fn (self &Xhci) wait_bios_release(legacy LegacySupport) bool {
	for _ in 0 .. 1_000_000 {
		if !legacy.bios_owned() {
			return true
		}
		cpu.spin_hint()
	}
	return false
}

pub fn (self &Xhci) take_ownership() bool {
	legacy := self.cap.legacy_support() or { return true }

	if legacy.bios_owned() {
		log.debug(c'Requesting xHCI ownership from BIOS')
		legacy.request_os_ownership()

		if !self.wait_bios_release(legacy) {
			log.error(c'xHCI BIOS handoff timed out')
			return false
		}

		log.debug(c'xHCI BIOS ownership released')
	}

	legacy.sanitize_smi()
	return true
}

pub fn (self &Xhci) reset_controller() bool {
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
