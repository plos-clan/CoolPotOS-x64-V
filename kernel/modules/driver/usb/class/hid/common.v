module hid

import bus { UsbInterface }
import defs
import log

pub struct HidDevice {
mut:
	iface            &UsbInterface
	ep_addr          u8
	report_desc_virt &u8 = unsafe { nil }
	report_desc_phys u64
	report_desc_len  u16
	buf_virt         &u8 = unsafe { nil }
	buf_phys         u64
	max_report_size  u16
	descriptor       HidDescriptor
}

pub fn HidDevice.new(iface &UsbInterface, ep_addr u8) ?HidDevice {
	desc_len := iface.extra_data.hid_report_desc_len

	if desc_len == 0 {
		log.error(c'HID: report descriptor length is 0')
		return none
	}

	desc_pages := (u64(desc_len) + 4095) / 4096
	desc_virt, desc_phys := kernel_page_table.alloc_dma(desc_pages)

	mut dev := HidDevice{
		iface:            unsafe { iface }
		ep_addr:          ep_addr
		report_desc_virt: &u8(desc_virt)
		report_desc_phys: desc_phys
		report_desc_len:  desc_len
	}

	dev.fetch_report_descriptor() or {
		kernel_page_table.dealloc_dma(desc_virt, desc_pages)
		return none
	}

	mut parser := HidParser.new(dev.report_desc_virt, dev.report_desc_len)
	dev.descriptor = parser.parse() or {
		log.error(c'HID: Failed to parse descriptor')
		kernel_page_table.dealloc_dma(desc_virt, desc_pages)
		return none
	}

	mut max_report_size := u32(0)
	for entry in dev.descriptor.reports.iter() {
		bytes := entry.val.size_bytes(.input)
		if bytes > max_report_size {
			max_report_size = bytes
		}
	}

	pages_needed := (u64(max_report_size) + 4095) / 4096
	buf_virt, buf_phys := kernel_page_table.alloc_dma(pages_needed)

	dev.buf_virt = &u8(buf_virt)
	dev.buf_phys = buf_phys
	dev.max_report_size = u16(max_report_size)

	dev.set_protocol(defs.proto_report)
	dev.set_idle(0)

	return dev
}

pub fn (mut self HidDevice) free() {
	self.descriptor.free()

	if self.buf_virt != 0 {
		kernel_page_table.dealloc_dma(u64(self.buf_virt), 1)
		self.buf_virt = unsafe { nil }
	}
	if self.report_desc_virt != 0 {
		pages := (u64(self.report_desc_len) + 4095) / 4096
		kernel_page_table.dealloc_dma(u64(self.report_desc_virt), pages)
		self.report_desc_virt = unsafe { nil }
	}
}

fn (mut self HidDevice) submit_transfer() {
	self.iface.device.submit_transfer(
		ep_addr:     self.ep_addr
		buffer_phys: self.buf_phys
		length:      self.max_report_size
	) or { log.error(c'HID: Submit transfer failed') }
}

fn (mut self HidDevice) set_protocol(proto u16) {
	self.iface.device.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_type_class | defs.req_rec_interface
			request:      defs.req_set_protocol
			value:        proto
			index:        self.iface.desc.interface_number
			length:       0
		}
		buffer_phys: 0
	) or { log.warn(c'HID: Set protocol failed (ignored)') }
}

fn (mut self HidDevice) set_idle(duration u16) {
	self.iface.device.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_type_class | defs.req_rec_interface
			request:      defs.req_set_idle
			value:        duration
			index:        self.iface.desc.interface_number
			length:       0
		}
		buffer_phys: 0
	) or { log.warn(c'HID: Set idle failed (ignored)') }
}

fn (mut self HidDevice) fetch_report_descriptor() ? {
	self.iface.device.submit_control(
		setup:       defs.SetupPacket{
			request_type: defs.req_dir_in | defs.req_rec_interface
			request:      defs.req_get_descriptor
			value:        (u16(defs.desc_report) << 8) | 0
			index:        self.iface.desc.interface_number
			length:       self.report_desc_len
		}
		buffer_phys: self.report_desc_phys
	) or {
		log.error(c'HID: Failed to fetch report descriptor')
		return none
	}
}
