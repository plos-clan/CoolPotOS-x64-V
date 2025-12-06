@[has_globals]
module hid

import bus {
	ControlTransferArgs,
	GeneralTransferArgs,
	UsbDriver,
	UsbInterface,
}
import defs
import log

pub fn probe(iface &UsbInterface) ?UsbDriver {
	if iface.desc.interface_class != defs.class_hid {
		return none
	}

	if iface.desc.interface_subclass != 1 {
		return none
	}

	if iface.desc.interface_protocol != 1 {
		return none
	}

	mut dev := iface.device
	if dev == unsafe { nil } {
		log.error(c'KBD: Interface has no parent device')
		return none
	}

	log.info(c'HID Keyboard found (Slot %d)', dev.slot_id)

	mut ep_addr := u8(0)
	mut found := false

	for ep in iface.endpoints.iter() {
		is_in := (ep.desc.endpoint_address & defs.req_dir_in) != 0
		is_int := (ep.desc.attributes & 0x03) == 0x03

		if is_in && is_int {
			ep_addr = ep.desc.endpoint_address
			found = true
			break
		}
	}

	if !found {
		log.error(c'KBD: No Interrupt IN endpoint found')
		return none
	}

	ptr := unsafe { C.malloc(sizeof(Keyboard)) }
	if ptr == 0 {
		return none
	}

	buf_virt, buf_phys := kernel_page_table.alloc_dma(1)

	mut kbd := unsafe { &Keyboard(ptr) }
	kbd.iface = unsafe { iface }
	kbd.ep_addr = ep_addr
	kbd.buf_virt = &u8(buf_virt)
	kbd.buf_phys = buf_phys

	dev.submit_control(ControlTransferArgs{
		setup:       defs.SetupPacket{
			request_type: 0x21
			request:      defs.req_set_protocol
			value:        0
			index:        u16(iface.desc.interface_number)
			length:       0
		}
		buffer_phys: 0
	}) or { log.error(c'KBD: Failed to set boot protocol') }

	dev.submit_control(ControlTransferArgs{
		setup:       defs.SetupPacket{
			request_type: 0x21
			request:      defs.req_set_idle
			value:        0
			index:        u16(iface.desc.interface_number)
			length:       0
		}
		buffer_phys: 0
	}) or { log.warn(c'KBD: Set Idle failed (ignored)') }

	log.info(c'KBD: Starting polling on EP 0x%x', kbd.ep_addr)

	dev.submit_transfer(GeneralTransferArgs{
		ep_addr:     kbd.ep_addr
		buffer_phys: kbd.buf_phys
		length:      8
	}) or {
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

fn (mut k Keyboard) process_input(status int, actual_len u32) {
	if status != 0 {
		log.warn(c'KBD: Transfer failed, status: %d', status)
		return
	}

	key := unsafe { k.buf_virt[2] }
	if key != 0 {
		log.info(c'Key Pressed: 0x%02x', key)
	}

	k.iface.device.submit_transfer(GeneralTransferArgs{
		ep_addr:     k.ep_addr
		buffer_phys: k.buf_phys
		length:      8
	}) or { log.error(c'KBD: Failed to resubmit transfer') }
}
