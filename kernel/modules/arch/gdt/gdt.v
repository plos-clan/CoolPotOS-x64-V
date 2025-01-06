module gdt

import log

__global (
	kernel_code_seg = u16(0x8)
	kernel_data_seg = u16(0x10)
	user_code_seg   = u16(0x23)
	user_data_seg   = u16(0x1b)
	tss_segment     = u16(0x28)
	gdt_pointer     GDTRegister
	gdt_entries     [7]u64
	tss             TaskStateSegment
	tss_stack       [1024]u8
)

@[packed]
struct GDTRegister {
	size    u16
	address voidptr
}

@[packed]
pub struct TaskStateSegment {
pub mut:
	unused0 u32
	rsp     [3]u64
	unused1 u64
	ist     [7]u64
	unused2 u64
	unused3 u16
	iopb    u16
}

pub fn init() {
	load_gdt()
	load_tss()
}

pub fn load_gdt() {
	gdt_entries[0] = 0x0000000000000000 // Null
	gdt_entries[1] = 0x00a09a0000000000 // Kernel code
	gdt_entries[2] = 0x00c0920000000000 // Kernel data
	gdt_entries[3] = 0x00c0f20000000000 // User data
	gdt_entries[4] = 0x00a0fa0000000000 // User code

	gdt_pointer = GDTRegister{
		size:    u16(sizeof(gdt_entries) - 1)
		address: &gdt_entries
	}

	asm volatile amd64 {
		lgdt ptr
		push cseg
		lea rax, [rip + 0x3]
		push rax
		lretq
		mov ds, dseg
		mov fs, dseg
		mov gs, dseg
		mov es, dseg
		mov ss, dseg
		; ; m (gdt_pointer) as ptr
		  rm (kernel_code_seg) as cseg
		  rm (kernel_data_seg) as dseg
		; memory
	}

	log.info(c'Global Descriptor Table loaded!\n')
}

pub fn load_tss() {
	address := u64(&tss)

	log.debug(c'TSS address: %#p\n', voidptr(address))

	low_base := (address & 0xffffff) << 16
	mid_base := ((address >> 24) & 0xff) << 56
	high_base := address >> 32

	access_byte := u64(0x89) << 40
	limit := u64(sizeof(TaskStateSegment) - 1)

	gdt_entries[5] = low_base | mid_base | limit | access_byte
	gdt_entries[6] = high_base

	tss.ist[0] = u64(&tss_stack) + sizeof(tss_stack)

	asm volatile amd64 {
		ltr offset
		; ; rm (tss_segment) as offset
		; memory
	}

	log.info(c'Task State Segment loaded!\n')
}
