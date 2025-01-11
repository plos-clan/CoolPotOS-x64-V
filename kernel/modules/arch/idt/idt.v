module idt

import log

__global (
	idt_pointer IDTPointer
	idt_entries [256]IDTEntry
)

@[packed]
struct IDTPointer {
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

pub enum InterruptIndex {
	timer = 32
	keyboard
	mouse
	hpet_timer
}

fn register_handler(vector u16, handler voidptr, ist u8, flags u8) {
	address := u64(handler)

	idt_entries[vector] = IDTEntry{
		offset_low: u16(address)
		selector:   kernel_code_seg
		ist:        ist & 0b111
		flags:      flags
		offset_mid: u16(address >> 16)
		offset_hi:  u32(address >> 32)
		reserved:   0
	}
}

pub fn init() {
	idt_pointer = IDTPointer{
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

	register_handler(u16(InterruptIndex.timer), timer, 0, 0x8e)
	register_handler(u16(InterruptIndex.keyboard), keyboard, 0, 0x8e)
	register_handler(u16(InterruptIndex.mouse), mouse, 0, 0x8e)
	register_handler(u16(InterruptIndex.hpet_timer), hpet_timer, 0, 0x8e)

	log.info(c'Interrupt Descriptor Table loaded!\n')
}

@[packed]
struct InterruptFrame {
	rip    u64
	cs     u64
	rflags u64
	rsp    u64
	ss     u64
}

fn (frame InterruptFrame) debug() {
	log.debug(c'Interrupt frame:\n')
	log.print(c'CS: %#x SS: %#x RFLAGS: %#x\n', frame.cs, frame.ss, frame.rflags)
	log.print(c'RIP: %#p RSP: %#p\n', frame.rip, frame.rsp)
}
