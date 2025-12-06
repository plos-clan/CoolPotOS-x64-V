module hid

import bus {
	CompletionEvent,
	UsbDriver,
	UsbInterface,
}
import defs
import log

pub fn probe_kbd(iface &UsbInterface) ?UsbDriver {
	if !iface.matches(defs.class_hid, 1, 1) {
		return none
	}

	ep := iface.find_endpoint(defs.ep_type_int, true) or {
		log.error(c'KBD: No Interrupt IN endpoint')
		return none
	}

	mut kbd := Keyboard.new(iface, ep.desc.endpoint_address)?
	log.info(c'HID Keyboard (Slot %d)', iface.device.slot_id)

	kbd.hid.submit_transfer(8)

	return kbd
}

pub struct Keyboard implements UsbDriver {
pub mut:
	hid HidDevice
}

pub fn Keyboard.new(iface &UsbInterface, ep_addr u8) ?&Keyboard {
	ptr := unsafe { C.malloc(sizeof(Keyboard)) }
	if ptr == 0 {
		return none
	}

	mut hid := HidDevice.new(iface, ep_addr)
	hid.init_boot_mode()

	mut kbd := unsafe { &Keyboard(ptr) }
	kbd.hid = hid

	return kbd
}

fn (mut self Keyboard) disconnect() {
	log.info(c'Keyboard disconnected')
	self.hid.free()
	C.free(self)
}

fn (mut self Keyboard) handle_completion(event CompletionEvent) {
	if event.ep_addr != self.hid.ep_addr {
		return
	}

	if event.status != .completed {
		log.warn(c'Keyboard transfer failed: %s', event.status)
		return
	}

	key := unsafe { self.hid.buf_virt[2] }
	if key != 0 {
		log.info(c'Key pressed: 0x%02x', key)
	}

	self.hid.submit_transfer(8)
}
