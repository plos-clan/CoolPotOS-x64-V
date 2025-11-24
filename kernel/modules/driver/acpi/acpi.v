@[has_globals]
module acpi

import limine
import log

__global (
	rsdp     &Rsdp
	root_sdt &RootSdt
	use_xsdt bool
)

@[_linker_section: '.limine_requests']
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
	rsdp = unsafe { &Rsdp(rsdp_request.response.address) }
	use_xsdt = rsdp.revision != 0
	log.debug(c'ACPI revision: %d', rsdp.revision)

	rsdt_addr := if use_xsdt { u64(rsdp.xsdt_address) } else { rsdp.rsdt_address }
	root_sdt = RootSdt.init(rsdt_addr)
	log.debug(c'ACPI root SDT at %#p', rsdt_addr)

	mcfg_ptr := root_sdt.find_sdt(c'MCFG') or { return }
	log.debug(c'Found MCFG at 0x%p', usize(mcfg_ptr))
	init_mcfg(mcfg_ptr)

	$if amd64 {
		madt_ptr := root_sdt.find_sdt(c'APIC') or { return }
		log.debug(c'Found MADT at 0x%p', usize(madt_ptr))
		init_madt(madt_ptr)

		hpet_ptr := root_sdt.find_sdt(c'HPET') or { return }
		log.debug(c'Found HPET at 0x%p', usize(hpet_ptr))
		hpet_init(hpet_ptr)
	}

	$if loongarch64 {
		spcr_ptr := root_sdt.find_sdt(c'SPCR') or { return }
		spcr_init(spcr_ptr)
	}
}
