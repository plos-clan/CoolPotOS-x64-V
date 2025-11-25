@[has_globals]
module acpi

import mem

__global (
	uart_addr   u64
	serial_init bool
)

@[packed]
struct Spcr {
	header         SdtHeader
	interface_type u8
	reserved       [3]u8
	base_addr      GenericAddress
}

fn spcr_init(table_addr voidptr) {
	spcr := unsafe { &Spcr(table_addr) }
	phys_addr := spcr.base_addr.address

	flags := mem.MappingType.kernel_data.flags()
	kernel_page_table.map_range_to(phys_addr, 0x1000, flags)

	uart_addr = mem.phys_to_virt(phys_addr)
	serial_init = true
}
