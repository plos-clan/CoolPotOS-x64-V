@[has_globals]
module pcie

import mem
import utils { Vec }

__global pci_devices Vec[PciDevice]

pub fn init() {
	flags := mem.MappingType.mmio_region.flags()

	for i in 0 .. pci_regions.length {
		region := pci_regions.at(i)

		base_addr := region.base_addr
		bus_count := u64(region.end_bus - region.start_bus) + 1
		region_size := bus_count * (1 << 20)

		kernel_page_table.map_range_to(base_addr, region_size, flags)

		mut scanner := PciScanner{
			segment: region.pci_seg_group
		}
		scanner.scan_region(region.start_bus, region.end_bus)
	}
}
