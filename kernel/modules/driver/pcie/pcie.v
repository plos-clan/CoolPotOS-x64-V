@[has_globals]
module pcie

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

import mem
import utils { Vec }

__global (
	pci_devices Vec[PciDevice]
)

pub fn init() {
	flags := mem.MappingType.kernel_data.flags()

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
	vendor_id := mmio_in[u16](&u16(base_addr))

	if vendor_id == 0xffff {
		return
	}

	device_id := mmio_in[u16](&u16(base_addr + 0x02))
	class_rev := mmio_in[u32](&u32(base_addr + 0x08))
	class_code := u8(class_rev >> 24)
	sub_class := u8(class_rev >> 16)

	header_type := mmio_in[u8](&u8(base_addr + 0x0e)) & 0x7f
	device_type := PciDeviceType.parse(class_code, sub_class)

	match header_type {
		0x00 {
			cmd_ptr := &u16(base_addr + 0x04)
			command := mmio_in[u16](cmd_ptr)
			mmio_out[u16](cmd_ptr, command | 0x7)

			device := PciDevice{
				address:     address
				vendor_id:   vendor_id
				device_id:   device_id
				class_code:  class_code
				sub_class:   sub_class
				revision:    u8(class_rev)
				device_type: device_type
				bars:        PciBar.scan(base_addr)
			}

			device.print_info()
			pci_devices.push(device)
		}
		0x01 {
			secondary_bus := mmio_in[u8](&u8(base_addr + 0x19))
			subordinate_bus := mmio_in[u8](&u8(base_addr + 0x1a))

			for bus in secondary_bus .. (subordinate_bus + 1) {
				scan_bus(address.segment(), bus)
			}
		}
		else {}
	}
}
