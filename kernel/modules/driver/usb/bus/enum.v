module bus

import defs {
	ConfigurationDescriptor,
	DeviceDescriptor,
	EndpointDescriptor,
	HidDescriptorHeader,
	InterfaceDescriptor,
	SetupPacket,
	SsEndpointCompanionDescriptor,
}
import log
import utils { Vec }

pub fn (mut dev UsbDevice) enumerate() ? {
	desc_virt, desc_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(desc_virt, 1) }

	dev.submit_control(
		setup:       SetupPacket{
			request_type: defs.req_dir_in
			request:      defs.req_get_descriptor
			value:        (u16(defs.desc_device) << 8) | 0
			length:       8
		}
		buffer_phys: desc_phys
	)?

	mut mps0 := u32(unsafe { &u8(desc_virt)[7] })

	if mps0 != 0 {
		if dev.speed >= defs.speed_super {
			mps0 = 1 << mps0
		}
		dev.host.update_ep0_mps(dev.slot_id, mps0) or {
			log.error(c'Failed to update EP0 MPS for slot %d', dev.slot_id)
			return none
		}
	}

	dev.submit_control(
		setup:       SetupPacket{
			request_type: defs.req_dir_in
			request:      defs.req_get_descriptor
			value:        (u16(defs.desc_device) << 8) | 0
			length:       u16(sizeof(DeviceDescriptor))
		}
		buffer_phys: desc_phys
	)?

	dev.desc = *&DeviceDescriptor(desc_virt)
	log.info(c'USB Device: %04x:%04x', dev.desc.id_vendor, dev.desc.id_product)

	header_virt, header_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(header_virt, 1) }

	dev.submit_control(
		setup:       SetupPacket{
			request_type: defs.req_dir_in
			request:      defs.req_get_descriptor
			value:        (u16(defs.desc_configuration) << 8) | 0
			length:       u16(sizeof(ConfigurationDescriptor))
		}
		buffer_phys: header_phys
	)?

	header := &ConfigurationDescriptor(header_virt)
	total_len := header.total_length
	config_val := header.configuration_value

	pages_needed := (u64(total_len) + 4095) / 4096
	config_virt, config_phys := kernel_page_table.alloc_dma(pages_needed)
	defer { kernel_page_table.dealloc_dma(config_virt, pages_needed) }

	dev.submit_control(
		setup:       SetupPacket{
			request_type: defs.req_dir_in
			request:      defs.req_get_descriptor
			value:        (u16(defs.desc_configuration) << 8) | 0
			length:       total_len
		}
		buffer_phys: config_phys
	)?

	log.debug(c'Parsing config tree (len: %d)', total_len)
	dev.parse_config_tree(&u8(config_virt), total_len)

	mut endpoints := Vec[UsbEndpoint]{}
	defer { endpoints.free() }

	for iface in dev.interfaces.iter() {
		if iface.desc.alternate_setting != 0 {
			continue
		}
		for endpoint in iface.endpoints.iter() {
			endpoints.push(*endpoint)
		}
	}

	log.debug(c'Configuring endpoints in hardware...')
	dev.host.configure_endpoints(dev.slot_id, &endpoints)?

	dev.submit_control(
		setup:       SetupPacket{
			request_type: defs.req_dir_out
			request:      defs.req_set_configuration
			value:        u16(config_val)
		}
		buffer_phys: 0
	)?

	dev.match_drivers()
	log.success(c'Device enumeration complete (slot %d)', dev.slot_id)
}

fn (mut dev UsbDevice) parse_config_tree(config_raw &u8, total_len u16) {
	mut offset := u16(0)

	for offset < total_len {
		ptr := unsafe { config_raw + offset }
		desc_len := unsafe { ptr[0] }
		desc_type := unsafe { ptr[1] }

		if offset + u16(desc_len) > total_len {
			break
		}

		match desc_type {
			defs.desc_interface { dev.parse_interface_descriptor(ptr) }
			defs.desc_hid { dev.parse_hid_descriptor(ptr) }
			defs.desc_endpoint { dev.parse_endpoint_descriptor(ptr) }
			defs.desc_ss_ep_companion { dev.parse_ss_companion(ptr) }
			else {}
		}

		offset += u16(desc_len)
	}
}

fn (mut dev UsbDevice) parse_interface_descriptor(ptr &u8) {
	desc := &InterfaceDescriptor(ptr)
	dev.interfaces.push(UsbInterface{ desc: *desc, device: dev })
}

fn (mut dev UsbDevice) parse_hid_descriptor(ptr &u8) {
	mut iface := dev.interfaces.last() or { return }
	header := &HidDescriptorHeader(ptr)

	mut pos := sizeof(HidDescriptorHeader)
	for _ in 0 .. header.num_descriptors {
		desc_type := unsafe { ptr[pos] }
		len_lo := unsafe { u16(ptr[pos + 1]) }
		len_hi := unsafe { u16(ptr[pos + 2]) }
		desc_len := len_lo | (len_hi << 8)

		if desc_type == defs.desc_report {
			iface.extra_data.hid_report_desc_len = desc_len
			return
		}
		pos += 3
	}
}

fn (mut dev UsbDevice) parse_ss_companion(ptr &u8) {
	mut iface := dev.interfaces.last() or { return }
	mut ep := iface.endpoints.last() or { return }

	desc := &SsEndpointCompanionDescriptor(ptr)
	ep.ss_desc = *desc
}

fn (mut dev UsbDevice) parse_endpoint_descriptor(ptr &u8) {
	mut iface := dev.interfaces.last() or { return }
	desc := &EndpointDescriptor(ptr)

	iface.endpoints.push(UsbEndpoint{ desc: *desc })
	dev.ep_map.set(desc.endpoint_address, u8(dev.interfaces.len - 1))
}
