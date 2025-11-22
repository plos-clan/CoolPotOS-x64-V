@[has_globals]
module mem

import limine
import log

@[_linker_section: '.limine_requests']
@[cinit]
__global (
	volatile hhdm_request = limine.HhdmRequest{
		response: unsafe { nil }
	}
)

__global (
	physical_memory_offset u64
)

pub fn init_hhdm() {
	physical_memory_offset = hhdm_request.response.offset
}

pub fn phys_to_virt(phys_addr u64) u64 {
	return phys_addr + physical_memory_offset
}

pub fn virt_to_phys(virt_addr u64) u64 {
	return virt_addr - physical_memory_offset
}
