@[has_globals]
module acpi

__global (
	uart_addr u32
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
	uart_addr = u32(spcr.base_addr.address)
}
