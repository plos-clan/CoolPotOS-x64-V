module hid

import bus {
	CompletionEvent,
	UsbDriver,
	UsbInterface,
}
import defs
import log
import utils { Vec }

struct KeyLayout {
mut:
	modifiers Vec[HidField]
	arrays    Vec[HidField]
	bitmaps   Vec[HidField]
}

pub struct Keyboard implements UsbDriver {
pub mut:
	hid    HidDevice
	layout KeyLayout
}

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

	kbd.hid.submit_transfer()
	return kbd
}

pub fn Keyboard.new(iface &UsbInterface, ep_addr u8) ?&Keyboard {
	mut hid := HidDevice.new(iface, ep_addr)?

	ptr := C.malloc(sizeof(Keyboard))
	if ptr == 0 {
		hid.free()
		return none
	}

	mut kbd := unsafe { &Keyboard(ptr) }
	kbd.hid = hid
	kbd.layout = KeyLayout{}
	kbd.scan_layout()

	return kbd
}

fn (mut self Keyboard) scan_layout() {
	for entry in self.hid.descriptor.reports.iter() {
		if entry.val.size_bytes(.input) == 0 {
			continue
		}
		for field in entry.val.fields.iter() {
			if field.kind != .input {
				continue
			}
			if field.is_const() || field.usage_page != 0x07 {
				continue
			}
			if !field.is_variable() {
				self.layout.arrays.push(*field)
				continue
			}
			usage := field.usage_min & 0xffff
			if usage >= 0xe0 && usage <= 0xe7 {
				self.layout.modifiers.push(*field)
			} else {
				self.layout.bitmaps.push(*field)
			}
		}
	}

	if self.layout.modifiers.len == 0 && self.layout.arrays.len == 0 {
		log.warn(c'KBD: No keyboard fields found')
	}
}

fn (mut self Keyboard) disconnect() {
	log.info(c'KBD: disconnected')
	self.hid.free()
	self.layout.modifiers.free()
	self.layout.arrays.free()
	self.layout.bitmaps.free()
	C.free(self)
}

fn (mut self Keyboard) handle_completion(event CompletionEvent) {
	if event.ep_addr != self.hid.ep_addr {
		return
	}

	if event.status != .completed && event.status != .short_packet {
		log.warn(c'KBD: Transfer failed (%d)', event.status)
		return
	}

	data := self.hid.buf_virt

	for mod in self.layout.modifiers.iter() {
		if mod.value(data, 0) == 1 {
			log.info(c'Key (Mod): 0x%02x', mod.usage_min & 0xFF)
		}
	}

	for arr in self.layout.arrays.iter() {
		for i in 0 .. arr.report_count {
			usage := arr.value(data, i)
			if usage > 1 {
				log.info(c'Key (Std): 0x%02x', usage)
			}
		}
	}

	for bmp in self.layout.bitmaps.iter() {
		if bmp.value(data, 0) == 1 {
			log.info(c'Key (Bmp): 0x%02x', bmp.usage_min & 0xFF)
		}
	}

	self.hid.submit_transfer()
}
