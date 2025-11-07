@[has_globals]
module acpi

import log

__global (
	hpet_addr u64
)

@[packed]
struct HpetInfo {
	header          SdtHeader
	event_block_id  u32
	base_addr       GenericAddress
	clock_tick_unit u16
	page_oem_flags  u8
}

fn hpet_init(table_addr voidptr) {
	hpet_info := unsafe { &HpetInfo(table_addr) }
	hpet_addr = hpet_info.base_addr.address
	log.debug(c'HPET base address: %#p', hpet_addr)
}
