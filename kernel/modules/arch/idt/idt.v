module idt

@[packed]
struct IDTRegister {
	size    u16
	address voidptr
}

@[packed]
struct IDTEntry {
pub mut:
	offset_low u16
	selector   u16
	ist        u8
	flags      u8
	offset_mid u16
	offset_hi  u32
	reserved   u32
}

__global (
	idt_pointer     IDTRegister
	idt_entries     [256]IDTEntry
)

pub fn init() {
	idt_pointer = IDTRegister{
		size:    u16((sizeof(IDTEntry) * 256) - 1)
		address: &idt_entries
	}

	asm volatile amd64 {
		lidt ptr
		; ; m (idt_pointer) as ptr
		; memory
	}

	register_handler(0, devide_by_zero, 0, 0x8e)
	register_handler(6, invalid_opcode, 0, 0x8e)
	register_handler(8, double_fault, 1, 0x8e)
	register_handler(11, segment_not_present, 0, 0x8e)
	register_handler(13, general_protection_fault, 0, 0x8e)
	register_handler(14, page_fault, 0, 0x8e)
}

pub fn register_handler(vector u16, handler voidptr, ist u8, flags u8) {
	address := u64(handler)

	idt_entries[vector] = IDTEntry{
		offset_low: u16(address)
		selector:   kernel_code_seg
		ist:        ist
		flags:      flags
		offset_mid: u16(address >> 16)
		offset_hi:  u32(address >> 32)
		reserved:   0
	}
}
