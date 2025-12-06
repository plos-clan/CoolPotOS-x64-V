module hid

import bus {
	UsbInterface,
}
import defs
import log

pub struct HidDevice {
pub mut:
	iface    &UsbInterface = unsafe { nil }
	ep_addr  u8
	buf_virt &u8 = unsafe { nil }
	buf_phys u64
}

pub fn HidDevice.new(iface &UsbInterface, ep_addr u8) HidDevice {
	buf_virt, buf_phys := kernel_page_table.alloc_dma(1)

	return HidDevice{
		iface:    unsafe { iface }
		ep_addr:  ep_addr
		buf_virt: &u8(buf_virt)
		buf_phys: buf_phys
	}
}

pub fn (mut self HidDevice) free() {
	kernel_page_table.dealloc_dma(u64(self.buf_virt), 1)
	self.buf_virt = unsafe { nil }
}

pub fn (mut self HidDevice) submit_transfer(len u32) {
	self.iface.device.submit_transfer(
		ep_addr:     self.ep_addr
		buffer_phys: self.buf_phys
		length:      len
	) or { log.error(c'HID: Submit transfer failed') }
}

pub fn (mut self HidDevice) init_boot_mode() {
	iface_idx := u16(self.iface.desc.interface_number)

	self.iface.device.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_type_class | defs.req_rec_interface
			request:      defs.req_set_protocol
			value:        defs.proto_boot
			index:        iface_idx
			length:       0
		}
		buffer_phys: 0
	) or { log.error(c'HID: Set Boot Protocol failed (ignored)') }

	self.iface.device.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_type_class | defs.req_rec_interface
			request:      defs.req_set_idle
			value:        0
			index:        iface_idx
			length:       0
		}
		buffer_phys: 0
	) or { log.warn(c'HID: Set Idle failed (ignored)') }
}
