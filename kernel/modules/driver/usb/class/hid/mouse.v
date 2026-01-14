module hid

import bus {
	CompletionEvent,
	UsbDriver,
	UsbInterface,
}
import defs
import log
import utils { Vec }

struct MouseLayout {
mut:
	axis_x     ?HidField
	axis_y     ?HidField
	axis_wheel ?HidField
	buttons    Vec[HidField]
}

pub struct Mouse implements UsbDriver {
pub mut:
	hid    HidDevice
	layout MouseLayout
}

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

	mouse.hid.submit_transfer()
	return mouse
}

pub fn Mouse.new(iface &UsbInterface, ep_addr u8) ?&Mouse {
	mut hid := HidDevice.new(iface, ep_addr)?

	ptr := C.malloc(sizeof(Mouse))
	if ptr == 0 {
		hid.free()
		return none
	}

	mut mouse := unsafe { &Mouse(ptr) }
	mouse.hid = hid
	mouse.layout = MouseLayout{}
	mouse.scan_layout()

	return mouse
}

fn (mut self Mouse) scan_layout() {
	for entry in self.hid.descriptor.reports.iter() {
		if entry.val.size_bytes(.input) == 0 {
			continue
		}
		for field in entry.val.fields.iter() {
			if field.kind != .input {
				continue
			}
			if field.is_const() || !field.is_variable() {
				continue
			}
			if field.usage_page == 0x01 {
				match field.usage_min & 0xffff {
					0x30 { self.layout.axis_x = *field }
					0x31 { self.layout.axis_y = *field }
					0x38 { self.layout.axis_wheel = *field }
					else {}
				}
			} else if field.usage_page == 0x09 {
				self.layout.buttons.push(*field)
			}
		}
	}

	if self.layout.axis_x == none && self.layout.buttons.len == 0 {
		log.warn(c'Mouse: No mouse fields found')
	}
}

fn (mut self Mouse) disconnect() {
	log.info(c'Mouse: disconnected')
	self.hid.free()
	self.layout.buttons.free()
	C.free(self)
}

fn (mut self Mouse) handle_completion(event CompletionEvent) {
	if event.ep_addr != self.hid.ep_addr {
		return
	}

	if event.status != .completed {
		log.warn(c'Mouse: transfer failed (%d)', event.status)
		return
	}

	data := self.hid.buf_virt

	if field := self.layout.axis_x {
		dx := field.value_signed(data, 0)
		log.info(c'Mouse (X): %d', dx)
	}

	if field := self.layout.axis_y {
		dy := field.value_signed(data, 0)
		log.info(c'Mouse (Y): %d', dy)
	}

	if field := self.layout.axis_wheel {
		wheel := field.value_signed(data, 0)
		log.info(c'Mouse (Wheel): %d', wheel)
	}

	for field in self.layout.buttons.iter() {
		for i in 0 .. field.report_count {
			if field.value(data, i) != 0 {
				btn_id := (field.usage_min + i) & 0xffff
				log.info(c'Mouse (Btn): %d', btn_id)
			}
		}
	}

	self.hid.submit_transfer()
}
