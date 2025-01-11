module mem

import arch.cpu

const pte_present = u64(1) << 0
const pte_writable = u64(1) << 1
const pte_user = u64(1) << 2
const pte_huge = u64(1) << 7
const pte_no_execute = u64(1) << 63
const pte_parent_flags = pte_present | pte_writable | pte_user

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
	if page_table := entry.table() {
		return page_table
	}

	frame := alloc_frames(1)?
	entry.set(u64(frame), pte_parent_flags)

	mut new_table := entry.table()?
	new_table.clear()
	return new_table
}

struct PageMapper {
mut:
	l4_table &PageTable
}

pub fn (table PageMapper) translate(addr u64) u64 {
	l4_index := (addr >> 39) & 0x1FF
	l3_index := (addr >> 30) & 0x1FF
	l2_index := (addr >> 21) & 0x1FF
	l1_index := (addr >> 12) & 0x1FF

	l4_table := table.l4_table
	if table.l4_table.entries[l4_index].huge() {
		return 0
	}

	l3_table := l4_table.entries[l4_index].table() or { return 0 }
	if l3_table.entries[l3_index].value == 0 {
		frame := l3_table.entries[l3_index].addr() & ~0x3fffffff
		offset := addr & 0x3fffffff
		return frame | offset
	}

	l2_table := l3_table.entries[l3_index].table() or { return 0 }
	if l2_table.entries[l2_index].huge() {
		frame := l2_table.entries[l2_index].addr() & ~0x1fffff
		offset := addr & 0x1fffff
		return frame | offset
	}

	l1_table := l2_table.entries[l2_index].table() or { return 0 }
	if l1_table.entries[l1_index].value == 0 {
		return 0
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

pub fn (mapper PageMapper) alloc_range(start u64, length u64, flags u64) {
	for addr := start; addr <= start + length - 1; addr += 0x1000 {
		frame := alloc_frames(1) or { 0 }
		mapper.map_to(addr, u64(frame), flags)
	}
}

pub fn (mapper PageMapper) map_range_to(frame u64, length u64, flags u64) {
	for offset := u64(0); offset < length; offset += 0x1000 {
		virt_addr := phys_to_virt(frame + offset)
		mapper.map_to(virt_addr, frame + offset, flags)
	}
}

pub fn init_paging() {
	l4_table_frame := cpu.read_cr3()
	mut l4_table := &PageTable(phys_to_virt(l4_table_frame))
	kernel_page_table = PageMapper{l4_table}
}

pub enum MappingType {
	user_code
	kernel_data
	user_data
}

pub fn (@type MappingType) flags() u64 {
	match @type {
		.user_code { return pte_present | pte_writable | pte_user }
		.kernel_data { return pte_present | pte_writable | pte_no_execute }
		.user_data { return pte_present | pte_writable | pte_user | pte_no_execute }
	}
}
