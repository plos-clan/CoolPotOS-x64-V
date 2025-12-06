module hid

import bus {
	UsbDriver,
	UsbInterface,
}
import defs
import log

pub fn probe(iface &UsbInterface) ?UsbDriver {
	if !iface.matches(defs.class_hid, 1, 1) {
		return none
	}

	mut dev := iface.device
	log.info(c'HID Keyboard found (Slot %d)', dev.slot_id)

	ep := iface.find_endpoint(defs.ep_type_int, true) or {
		log.error(c'KBD: No Interrupt IN endpoint found')
		return none
	}

	ptr := C.malloc(sizeof(Keyboard))
	if ptr == 0 {
		return none
	}

	buf_virt, buf_phys := kernel_page_table.alloc_dma(1)

	mut kbd := unsafe { &Keyboard(ptr) }
	kbd.iface = unsafe { iface }
	kbd.ep_addr = ep.desc.endpoint_address
	kbd.buf_virt = &u8(buf_virt)
	kbd.buf_phys = buf_phys

	dev.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_type_class | defs.req_rec_interface
			request:      defs.req_set_protocol
			value:        defs.proto_boot
			index:        u16(iface.desc.interface_number)
			length:       0
		}
		buffer_phys: 0
	) or { log.error(c'KBD: Failed to set boot protocol') }

	dev.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_type_class | defs.req_rec_interface
			request:      defs.req_set_idle
			value:        0
			index:        u16(iface.desc.interface_number)
			length:       0
		}
		buffer_phys: 0
	) or { log.warn(c'KBD: Set Idle failed (ignored)') }

	log.info(c'KBD: Starting polling on EP 0x%x', kbd.ep_addr)

	dev.submit_transfer(
		ep_addr:     kbd.ep_addr
		buffer_phys: kbd.buf_phys
		length:      8
	) or {
		log.error(c'KBD: Failed to start polling')
		kernel_page_table.dealloc_dma(u64(kbd.buf_virt), 1)
		return none
	}

	return kbd
}

pub struct Keyboard implements UsbDriver {
pub mut:
	iface    &UsbInterface = unsafe { nil }
	ep_addr  u8
	buf_virt &u8 = unsafe { nil }
	buf_phys u64
}

fn (mut k Keyboard) disconnect() {
	log.info(c'Keyboard disconnected')
	kernel_page_table.dealloc_dma(u64(k.buf_virt), 1)
	C.free(k)
}

fn (mut k Keyboard) handle_completion(ep_addr u8, status int, len u32) {
	if ep_addr != k.ep_addr {
		return
	}

	if status != 0 {
		log.warn(c'KBD: Transfer failed: %d', status)
		return
	}

	key := unsafe { k.buf_virt[2] }
	if key != 0 {
		log.info(c'Key Pressed: 0x%02x', key)
	}

	k.iface.device.submit_transfer(
		ep_addr:     k.ep_addr
		buffer_phys: k.buf_phys
		length:      8
	) or { log.error(c'KBD: Resubmit failed') }
}
