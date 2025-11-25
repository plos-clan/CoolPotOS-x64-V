module core

import log
import regs

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub fn (mut self Xhci) check_ports() {
	max_ports := int(self.cap.max_ports())
	log.info(c'Scanning %d USB ports...', max_ports)

	for i in 0 .. max_ports {
		mut port := regs.Port.new(self.op.base_addr, i)
		self.setup_port(mut port)
	}
}

fn (mut self Xhci) setup_port(mut port regs.Port) {
	status := port.read_portsc()

	if (status & regs.port_ccs) == 0 {
		return
	}

	if (status & regs.port_csc) != 0 {
		port.clear_change_bit(regs.port_csc)
	}

	if (status & regs.port_ped) != 0 {
		log.debug(c'Port %d already connected and enabled', port.id)
		return
	}

	log.debug(c'Port %d connected, resetting...', port.id)

	if port.reset() && self.wait_port_reset(port) {
		log.info(c'Port %d successfully enabled', port.id)
	} else {
		log.warn(c'Port %d failed to initialize', port.id)
	}
}

fn (self Xhci) wait_port_reset(port regs.Port) bool {
	success_mask := u32(regs.port_ped | regs.port_prc)

	for _ in 0 .. 1_000_000 {
		status := port.read_portsc()

		if (status & regs.port_pr) != 0 {
			cpu.spin_hint()
			continue
		}

		if (status & success_mask) == 0 {
			cpu.spin_hint()
			continue
		}

		speed_id := (status >> 10) & 0xf
		log.debug(c'Port %d reset complete (speed: %d)', port.id, speed_id)

		if (status & regs.port_prc) != 0 {
			port.clear_change_bit(regs.port_prc)
		}
		return true
	}

	log.error(c'Port %d reset timeout', port.id)
	return false
}
