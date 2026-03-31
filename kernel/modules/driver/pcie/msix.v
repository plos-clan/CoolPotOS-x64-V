module pcie

import mem

$if amd64 {
	import arch.amd64.cpu { mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_out }
}

pub struct MsiXTable {
pub:
	base_addr   u64
	entry_count u32
}

pub fn MsiXTable.new(bar PciBar, offset u32, count u32) ?MsiXTable {
	if bar.address == 0 {
		return none
	}

	addr := mem.phys_to_virt(bar.address) + u64(offset)
	return MsiXTable{
		base_addr:   addr
		entry_count: count
	}
}

pub struct MsiXTableEntry {
pub:
	entry_addr u64
}

pub fn (t MsiXTable) entry(index u32) ?MsiXTableEntry {
	if index >= t.entry_count {
		return none
	}
	entry_addr := t.base_addr + u64(index * 16)
	return MsiXTableEntry{entry_addr}
}

pub fn (e MsiXTableEntry) write(address u64, data u32, masked bool) {
	mmio_out[u32](e.entry_addr, u32(address))
	mmio_out[u32](e.entry_addr + 4, u32(address >> 32))
	mmio_out[u32](e.entry_addr + 8, data)
	ctrl := if masked { u32(1) } else { 0 }
	mmio_out[u32](e.entry_addr + 12, ctrl)
}
