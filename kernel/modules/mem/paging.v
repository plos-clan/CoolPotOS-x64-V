@[has_globals]
module mem

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}
import log

$if amd64 {
	const pte_present = u64(1) << 0
	const pte_writable = u64(1) << 1
	const pte_user = u64(1) << 2
	const pte_no_cache = u64(1) << 4
	const pte_huge = u64(1) << 7
	const pte_no_execute = u64(1) << 63
	const pte_parent_flags = pte_present | pte_writable | pte_user
} $else {
	const pte_valid = u64(1) << 0
	const pte_dirty = u64(1) << 1
	const pte_plv_user = u64(3) << 2
	const pte_mat_cc = u64(1) << 4
	const pte_global = u64(1) << 6
	const pte_huge = u64(1) << 6
	const pte_no_execute = u64(1) << 62
	const pte_parent_flags = 0
}

__global (
	kernel_page_table PageMapper
)

@[packed]
struct PageTable {
mut:
	entries [512]PageTableEntry
}

fn (mut table PageTable) clear() {
	for mut entry in table.entries {
		entry.value = 0
	}
}

@[packed]
struct PageTableEntry {
mut:
	value u64
}

fn (entry PageTableEntry) addr() u64 {
	return entry.value & 0x000ffffffffff000
}

fn (entry PageTableEntry) huge() bool {
	return entry.value & pte_huge != 0
}

fn (mut entry PageTableEntry) set(frame u64, flags u64) {
	entry.value = frame | flags
}

fn (entry PageTableEntry) table() ?&PageTable {
	if entry.value == 0 {
		return none
	}
	addr := phys_to_virt(entry.addr())
	return &PageTable(addr)
}

fn (mut entry PageTableEntry) create() ?&PageTable {
	return entry.table() or {
		frame := alloc_frames(1)?
		entry.set(u64(frame), pte_parent_flags)
		mut table := entry.table()?
		table.clear()
		return table
	}
}

struct PageMapper {
mut:
	l4_table &PageTable
}

pub fn (table PageMapper) translate(addr u64) ?u64 {
	l4_index := (addr >> 39) & 0x1ff
	l3_index := (addr >> 30) & 0x1ff
	l2_index := (addr >> 21) & 0x1ff
	l1_index := (addr >> 12) & 0x1ff

	l4_table := table.l4_table
	if l4_table.entries[l4_index].huge() {
		return none
	}

	l3_table := l4_table.entries[l4_index].table()?
	if l3_table.entries[l3_index].value == 0 {
		frame := l3_table.entries[l3_index].addr() & ~0x3fffffff
		offset := addr & 0x3fffffff
		return frame | offset
	}

	l2_table := l3_table.entries[l3_index].table()?
	if l2_table.entries[l2_index].huge() {
		frame := l2_table.entries[l2_index].addr() & ~0x1fffff
		offset := addr & 0x1fffff
		return frame | offset
	}

	l1_table := l2_table.entries[l2_index].table()?
	if l1_table.entries[l1_index].value == 0 {
		return none
	}

	return l1_table.entries[l1_index].addr() | (addr & 0xfff)
}

pub fn (table PageMapper) map_to(addr u64, frame u64, flags u64) ? {
	l4_index := (addr >> 39) & 0x1FF
	l3_index := (addr >> 30) & 0x1FF
	l2_index := (addr >> 21) & 0x1FF
	l1_index := (addr >> 12) & 0x1FF

	mut l4_table := table.l4_table
	mut l3_table := l4_table.entries[l4_index].create()?
	mut l2_table := l3_table.entries[l3_index].create()?
	mut l1_table := l2_table.entries[l2_index].create()?
	l1_table.entries[l1_index].set(frame, flags)

	cpu.invlpg(addr)
}

pub fn (table PageMapper) unmap(addr u64) ? {
	l4_index := (addr >> 39) & 0x1FF
	l3_index := (addr >> 30) & 0x1FF
	l2_index := (addr >> 21) & 0x1FF
	l1_index := (addr >> 12) & 0x1FF

	mut l4_table := table.l4_table
	mut l3_table := l4_table.entries[l4_index].table()?
	mut l2_table := l3_table.entries[l3_index].table()?
	mut l1_table := l2_table.entries[l2_index].table()?
	l1_table.entries[l1_index].value = 0

	cpu.invlpg(addr)
}

pub fn (self PageMapper) alloc_dma(page_count u64) (u64, u64) {
	phys_addr := u64(alloc_frames(page_count) or {
		log.panic(c'Failed to allocate %d frames', page_count)
	})

	virt_addr := phys_to_virt(phys_addr)
	flags := MappingType.mmio_region.flags()

	self.map_range_to(phys_addr, page_count * 0x1000, flags)
	C.memset(voidptr(virt_addr), 0, usize(page_count * 0x1000))

	return virt_addr, phys_addr
}

pub fn (self PageMapper) dealloc_dma(virt_addr u64, page_count u64) {
	for offset := u64(0); offset < page_count * 0x1000; offset += 0x1000 {
		self.unmap(virt_addr + offset) or {
			log.panic(c'Failed to deallocate %#lx', virt_addr + offset)
		}
	}
}

pub fn (self PageMapper) alloc_range(start u64, len u64, flags u64) {
	for addr := start; addr <= start + len - 1; addr += 0x1000 {
		phys_addr := alloc_frames(1) or { return }
		self.map_to(addr, u64(phys_addr), flags)
	}
}

pub fn (self PageMapper) map_range_to(frame u64, len u64, flags u64) {
	for offset := u64(0); offset < len; offset += 0x1000 {
		virt_addr := phys_to_virt(frame + offset)
		self.map_to(virt_addr, frame + offset, flags)
	}
}

pub fn init_paging() {
	$if amd64 {
		l4_table_frame := cpu.read_cr3()
		mut l4_table := &PageTable(phys_to_virt(l4_table_frame))
		kernel_page_table = PageMapper{l4_table}
	} $else {
		l4_table_frame := cpu.read_pgdh()
		mut l4_table := &PageTable(phys_to_virt(l4_table_frame))
		kernel_page_table = PageMapper{l4_table}
	}
}

pub enum MappingType {
	user_code
	user_data
	mmio_region
	kernel_data
}

pub fn (@type MappingType) flags() u64 {
	$if amd64 {
		return match @type {
			.user_code { pte_present | pte_writable | pte_user }
			.user_data { pte_present | pte_writable | pte_user | pte_no_execute }
			.mmio_region { pte_present | pte_writable | pte_no_cache | pte_no_execute }
			.kernel_data { pte_present | pte_writable | pte_no_execute }
		}
	} $else {
		return match @type {
			.user_code { pte_valid | pte_dirty | pte_plv_user | pte_mat_cc }
			.user_data { pte_valid | pte_dirty | pte_plv_user | pte_mat_cc | pte_no_execute }
			.mmio_region { pte_valid | pte_dirty | pte_plv_user }
			.kernel_data { pte_valid | pte_dirty | pte_global | pte_mat_cc | pte_no_execute }
		}
	}
}
