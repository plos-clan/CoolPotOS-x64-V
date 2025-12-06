module hid

import bus {
	CompletionEvent,
	UsbDriver,
	UsbInterface,
}
import defs
import log

pub fn probe_mouse(iface &UsbInterface) ?UsbDriver {
	if !iface.matches(defs.class_hid, 1, 2) {
		return none
	}

	ep := iface.find_endpoint(defs.ep_type_int, true) or {
		log.error(c'Mouse: No Interrupt IN endpoint')
		return none
	}

	mut mouse := Mouse.new(iface, ep.desc.endpoint_address)?
	log.info(c'HID Mouse (Slot %d)', iface.device.slot_id)

	mouse.hid.submit_transfer(4)

	return mouse
}

pub struct Mouse implements UsbDriver {
pub mut:
	hid HidDevice
}

pub fn Mouse.new(iface &UsbInterface, ep_addr u8) ?&Mouse {
	ptr := unsafe { C.malloc(sizeof(Mouse)) }
	if ptr == 0 {
		return none
	}

	mut hid := HidDevice.new(iface, ep_addr)
	hid.init_boot_mode()

	mut mouse := unsafe { &Mouse(ptr) }
	mouse.hid = hid

	return mouse
}

fn (mut self Mouse) disconnect() {
	log.info(c'Mouse disconnected')
	self.hid.free()
	C.free(self)
}

fn (mut self Mouse) handle_completion(event CompletionEvent) {
	if event.ep_addr != self.hid.ep_addr {
		return
	}

	if event.status != .completed {
		log.warn(c'Mouse transfer failed: %s', event.status)
		return
	}

	buttons := unsafe { self.hid.buf_virt[0] }
	dx := unsafe { i8(self.hid.buf_virt[1]) }
	dy := unsafe { i8(self.hid.buf_virt[2]) }

	if buttons != 0 || dx != 0 || dy != 0 {
		log.info(c'Mouse: Btn=%02x dX=%d dY=%d', buttons, dx, dy)
	}

	self.hid.submit_transfer(4)
}
