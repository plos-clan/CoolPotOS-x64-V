module unet

import bus {
	CompletionEvent,
	UsbDriver,
	UsbInterface,
}
import defs
import log

pub struct RndisDevice implements UsbDriver {
pub mut:
	ctrl_iface    &UsbInterface = unsafe { nil }
	data_iface    &UsbInterface = unsafe { nil }
	ep_intr       u8
	ep_bulk_in    u8
	ep_bulk_out   u8
	ctrl_buf_virt &u8 = unsafe { nil }
	ctrl_buf_phys u64
	rx_buf_virt   &u8 = unsafe { nil }
	rx_buf_phys   u64
	tx_buf_virt   &u8 = unsafe { nil }
	tx_buf_phys   u64
	mac_addr      [6]u8
}

pub fn probe_rndis(iface &UsbInterface) ?UsbDriver {
	if !iface.matches(defs.class_wireless, 0x01, 0x03)
		&& !iface.matches(defs.class_comm, 0x02, 0xff) {
		return none
	}

	data_iface := iface.find_sibling(defs.class_data, 0xff, 0xff) or {
		log.warn(c'RNDIS: Found control interface, but missing data interface')
		return none
	}

	ep_intr := iface.find_endpoint(defs.ep_type_int, true) or {
		log.error(c'RNDIS: No Interrupt IN endpoint')
		return none
	}
	ep_bulk_in := data_iface.find_endpoint(defs.ep_type_bulk, true) or {
		log.error(c'RNDIS: No Bulk IN endpoint')
		return none
	}
	ep_bulk_out := data_iface.find_endpoint(defs.ep_type_bulk, false) or {
		log.error(c'RNDIS: No Bulk OUT endpoint')
		return none
	}

	mut rndis := RndisDevice.new(
		ctrl_iface:  unsafe { iface }
		data_iface:  data_iface
		ep_intr:     ep_intr.desc.endpoint_address
		ep_bulk_in:  ep_bulk_in.desc.endpoint_address
		ep_bulk_out: ep_bulk_out.desc.endpoint_address
	)?

	log.info(c'Probing RNDIS device on slot %d...', iface.device.slot_id)
	return none
}

@[params]
pub struct RndisDeviceConfig {
pub:
	ctrl_iface  &UsbInterface = unsafe { nil }
	data_iface  &UsbInterface = unsafe { nil }
	ep_intr     u8
	ep_bulk_in  u8
	ep_bulk_out u8
}

pub fn RndisDevice.new(config &RndisDeviceConfig) ?&RndisDevice {
	ptr := C.malloc(sizeof(RndisDevice))
	if ptr == 0 {
		return none
	}

	mut dev := unsafe { &RndisDevice(ptr) }
	dev.ctrl_iface = config.ctrl_iface
	dev.data_iface = config.data_iface
	dev.ep_intr = config.ep_intr
	dev.ep_bulk_in = config.ep_bulk_in
	dev.ep_bulk_out = config.ep_bulk_out

	ctrl_virt, ctrl_phys := kernel_page_table.alloc_dma(1)
	dev.ctrl_buf_virt = &u8(ctrl_virt)
	dev.ctrl_buf_phys = ctrl_phys

	rx_virt, rx_phys := kernel_page_table.alloc_dma(4)
	dev.rx_buf_virt = &u8(rx_virt)
	dev.rx_buf_phys = rx_phys

	tx_virt, tx_phys := kernel_page_table.alloc_dma(4)
	dev.tx_buf_virt = &u8(tx_virt)
	dev.tx_buf_phys = tx_phys

	return dev
}

fn (mut self RndisDevice) free() {
	if self.ctrl_buf_virt != unsafe { nil } {
		kernel_page_table.dealloc_dma(u64(self.ctrl_buf_virt), 1)
	}
	if self.rx_buf_virt != unsafe { nil } {
		kernel_page_table.dealloc_dma(u64(self.rx_buf_virt), 4)
	}
	if self.tx_buf_virt != unsafe { nil } {
		kernel_page_table.dealloc_dma(u64(self.tx_buf_virt), 4)
	}
	C.free(self)
}

fn (mut self RndisDevice) disconnect() {
	log.info(c'RNDIS Device disconnected')
	self.free()
}

fn (mut self RndisDevice) handle_completion(event CompletionEvent) {
}
