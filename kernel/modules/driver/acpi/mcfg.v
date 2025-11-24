@[has_globals]
module acpi

__global (
	pci_regions PciRegions
)

@[packed]
struct Mcfg {
	header   SdtHeader
	reserved u64
}

@[packed]
pub struct McfgEntry {
pub:
	base_addr     u64
	pci_seg_group u16
	start_bus     u8
	end_bus       u8
	reserved      u32
}

pub fn init_mcfg(table_addr voidptr) {
	mcfg := unsafe { &Mcfg(table_addr) }

	data_len := usize(mcfg.header.length) - sizeof(Mcfg)
	count := data_len / sizeof(McfgEntry)

	pci_regions = PciRegions{
		regions: &McfgEntry(usize(table_addr) + sizeof(Mcfg))
		length:  count
	}
}

pub struct PciRegions {
pub:
	regions &McfgEntry
	length  usize
}

pub fn (regions &PciRegions) at(index usize) &McfgEntry {
	base_addr := usize(regions.regions)
	return &McfgEntry(base_addr + (index * sizeof(McfgEntry)))
}
