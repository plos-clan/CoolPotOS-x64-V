@[has_globals]
module pcie

import mem
import utils { Vec }

__global (
	pci_devices Vec[PciDevice]
)

pub fn init() {
	flags := mem.MappingType.mmio_region.flags()

	for i in 0 .. pci_regions.length {
		region := pci_regions.at(i)

		base_addr := region.base_addr
		bus_count := u64(region.end_bus - region.start_bus) + 1
		region_size := bus_count * (1 << 20)

		kernel_page_table.map_range_to(base_addr, region_size, flags)
		scan_segment(region.pci_seg_group)
	}
}

fn scan_segment(segment u16) {
	scan_bus(segment, 0)

	address := PciAddress.new(segment, 0, 0, 0)
	if address.has_multi_funcs() {
		for bus in 1 .. 8 {
			scan_bus(segment, bus)
		}
	}
}

fn scan_bus(segment u16, bus u8) {
	for device in 0 .. 32 {
		address := PciAddress.new(segment, bus, device, 0)
		scan_function(address)

		if address.has_multi_funcs() {
			for function in 1 .. 8 {
				scan_function(PciAddress.new(segment, bus, device, function))
			}
		}
	}
}

fn scan_function(address PciAddress) {
	base_addr := address.mmio_address()
	header := PciHeader{base_addr}

	vendor_id := header.vendor_id()
	if vendor_id == 0xffff {
		return
	}

	class_code := header.class_code()
	sub_class := header.sub_class()
	device_type := PciDeviceType.parse(class_code, sub_class)

	match header.header_type() {
		.endpoint {
			endpoint := EndpointHeader{header}
			base_flags := pci_cmd_memory_space | pci_cmd_io_space | pci_cmd_bus_master
			header.update_command(base_flags, true)
			header.update_command(pci_cmd_intx_disable, true)

			device := PciDevice{
				address:     address
				vendor_id:   vendor_id
				device_id:   header.device_id()
				class_code:  class_code
				sub_class:   sub_class
				prog_if:     header.prog_if()
				revision:    header.revision()
				device_type: device_type
				bars:        endpoint.bars()
				interrupt:   PciInterrupt.resolve(endpoint)
			}

			device.print_info()
			pci_devices.push(device)
		}
		.pci_pci_bridge {
			bridge := BridgeHeader{header}
			for bus in bridge.secondary_bus() .. (bridge.subordinate_bus() + 1) {
				scan_bus(address.segment(), bus)
			}
		}
		else {}
	}
}
