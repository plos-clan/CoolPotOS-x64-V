module core

import bus
import log
import regs

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

fn (self &Xhci) wait_port_reset(port regs.Port) bool {
	for _ in 0 .. 1_000_000 {
		if port.has_reset_change() {
			port.update_portsc(regs.port_prc)
			if port.is_enabled() {
				return true
			}
		}
		if !port.is_in_reset() && port.is_enabled() {
			return true
		}
		cpu.spin_hint()
	}

	log.error(c'Port %d reset timeout', port.id)
	return false
}

pub fn (mut self Xhci) check_ports() {
	max_ports := self.cap.max_ports()
	log.info(c'Scanning %d USB ports...', max_ports)

	for i in 0 .. max_ports {
		mut port := regs.Port.new(self.op.base_addr, i)
		self.handle_port(port)
	}
}

fn (mut self Xhci) handle_port(port regs.Port) {
	if !port.is_connected() {
		return
	}

	if port.has_connect_change() {
		port.update_portsc(regs.port_csc)
	}

	if port.is_enabled() {
		log.debug(c'Port %d already enabled', port.id)
		return
	}

	self.attach_device(port)
}

fn (mut self Xhci) attach_device(port regs.Port) {
	log.debug(c'Port %d connected, resetting...', port.id)

	if !port.reset() || !self.wait_port_reset(port) {
		log.warn(c'Port %d reset failed', port.id)
		return
	}

	slot_id := self.enable_slot() or {
		log.error(c'Failed to enable slot for port %d', port.id)
		return
	}

	log.info(c'Device assigned to slot %d', slot_id)

	self.setup_slot_device(port, slot_id) or {
		log.error(c'Device init failed for slot %d', slot_id)
		self.cleanup_slot_on_failure(slot_id)
	}
}

fn (mut self Xhci) setup_slot_device(port regs.Port, slot_id u8) ? {
	speed_id := port.speed_id()
	log.info(c'Port %d enabled (speed: %d)', port.id, speed_id)

	self.address_device(port.id, slot_id, speed_id)?

	mut dev := bus.UsbDevice.new(
		host:    self
		slot_id: slot_id
		port_id: port.id
		speed:   speed_id
	)

	self.slots[slot_id].usb_device = dev

	dev.enumerate() or {
		log.error(c'Enumeration failed for slot %d', slot_id)
		dev.free()
		self.slots[slot_id].usb_device = unsafe { nil }
		return none
	}
}
