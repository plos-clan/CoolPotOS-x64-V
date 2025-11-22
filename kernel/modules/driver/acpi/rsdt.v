module acpi

import mem

@[packed]
struct RootSdt {
	header     SdtHeader
	ptrs_start voidptr
}

@[packed]
struct SdtHeader {
	signature        [4]u8
	length           u32
	revision         u8
	checksum         u8
	oem_id           [6]u8
	oem_table_id     [8]u8
	oem_revision     u32
	creator_id       u32
	creator_revision u32
}

@[inline]
fn (self RootSdt) size() u64 {
	ptr_size := u32(if use_xsdt { 8 } else { 4 })
	data_length := self.header.length - sizeof(SdtHeader)
	return data_length / ptr_size
}

@[inline]
fn (self RootSdt) entry(index u64) u64 {
	unsafe {
		return if use_xsdt {
			&u64(&root_sdt.ptrs_start)[index]
		} else {
			&u32(&root_sdt.ptrs_start)[index]
		}
	}
}

fn (self RootSdt) find_sdt(name &char) ?voidptr {
	for i := u64(0); i < self.size(); i++ {
		ptr := mem.phys_to_virt(self.entry(i))
		signature := &SdtHeader(ptr).signature

		unsafe {
			if C.memcmp(voidptr(&signature), name, 4) == 0 {
				return voidptr(ptr)
			}
		}
	}

	return none
}

fn RootSdt.init(addr u64) &RootSdt {
	flags := mem.MappingType.kernel_data.flags()

	kernel_page_table.map_range_to(addr, 0x1000, flags)
	root_sdt = &RootSdt(mem.phys_to_virt(addr))

	base_addr := u64(root_sdt.ptrs_start)
	kernel_page_table.map_range_to(base_addr, 0x1000, flags)

	for i := u64(0); i < root_sdt.size(); i++ {
		ptr := u64(root_sdt.entry(i))
		kernel_page_table.map_range_to(ptr, 0x1000, flags)
	}

	return root_sdt
}
