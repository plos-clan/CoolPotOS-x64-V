module bus

import defs {
	ConfigurationDescriptor,
	DeviceDescriptor,
	EndpointDescriptor,
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
		desc_len := unsafe { config_raw[offset] }
		desc_type := unsafe { config_raw[offset + 1] }

		if offset + u16(desc_len) > total_len {
			break
		}

		match desc_type {
			defs.desc_interface {
				iface_desc := &InterfaceDescriptor(config_raw + offset)
				dev.interfaces.push(UsbInterface{ desc: *iface_desc, device: &dev })
			}
			defs.desc_endpoint {
				if mut iface := dev.interfaces.last() {
					ep_desc := &EndpointDescriptor(config_raw + offset)
					iface.endpoints.push(UsbEndpoint{ desc: *ep_desc })
					iface_idx := u8(dev.interfaces.len - 1)
					dev.ep_map.set(ep_desc.endpoint_address, iface_idx)
				}
			}
			defs.desc_ss_ep_companion {
				if mut iface := dev.interfaces.last() {
					if mut ep := iface.endpoints.last() {
						ss_desc := &SsEndpointCompanionDescriptor(config_raw + offset)
						ep.ss_desc = *ss_desc
					}
				}
			}
			else {}
		}

		offset += u16(desc_len)
	}
}
