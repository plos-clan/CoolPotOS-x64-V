@[has_globals]
module acpi

import wenxuanjun.limine
import log
import mem

__global (
	rsdp     &Rsdp
	root_sdt &RootSdt
	use_xsdt bool
)

@[_linker_section: '.requests']
@[cinit]
__global (
	volatile rsdp_request = limine.RsdpRequest{
		response: unsafe { nil }
	}
)

@[packed]
struct Rsdp {
	signature    [8]u8
	checksum     u8
	oem_id       [6]u8
	revision     u8
	rsdt_address u32
	length       u32
	xsdt_address u64
	ext_checksum u8
	reserved     [3]u8
}

@[packed]
struct GenericAddress {
	address_space u8
	bit_width     u8
	bit_offset    u8
	access_size   u8
	address       u64
}

pub fn init() {
	flags := mem.MappingType.kernel_data.flags()
	rsdp_addr := u64(rsdp_request.response.address)
	kernel_page_table.map_range_to(rsdp_addr, 0x1000, flags)

	rsdp = &Rsdp(mem.phys_to_virt(rsdp_addr))
	use_xsdt = rsdp.revision != 0
	log.debug(c'ACPI revision: %d\n', rsdp.revision)

	rsdt_addr := if use_xsdt { u64(rsdp.xsdt_address) } else { rsdp.rsdt_address }
	root_sdt = RootSdt.init(rsdt_addr)
	log.debug(c'ACPI root SDT at %#p\n', rsdt_addr)

	madt_ptr := root_sdt.find_sdt(c'APIC') or { return }
	log.info(c'Found MADT at 0x%p\n', usize(madt_ptr))
	init_madt(madt_ptr)

	hpet_ptr := root_sdt.find_sdt(c'HPET') or { return }
	log.info(c'Found HPET at 0x%p\n', usize(hpet_ptr))
	hpet_init(hpet_ptr)
}
