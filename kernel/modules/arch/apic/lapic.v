@[has_globals]
module apic

import arch.cpu
import arch.idt
import limine
import mem
import log

const lapic_reg_id = 0x20
const lapic_reg_eoi = 0xb0
const lapic_reg_spurious = 0xf0
const lapic_reg_timer = 0x320
const lapic_reg_timer_initcnt = 0x380
const lapic_reg_timer_curcnt = 0x390
const lapic_reg_timer_div = 0x3e0
const lapic_timer_freq_hz = 250

@[_linker_section: '.requests']
@[cinit]
__global (
	volatile mp_request = limine.MpRequest{
		response: unsafe { nil }
		flags:    1
	}
)

struct Lapic {
mut:
	base_addr   u64
	x2apic_mode bool
}

@[inline]
pub fn (self Lapic) eoi() {
	self.write(lapic_reg_eoi, 0)
}

@[inline]
pub fn (self Lapic) id() u64 {
	return self.read(lapic_reg_id)
}

fn (self Lapic) read(reg u32) u64 {
	if self.x2apic_mode {
		return cpu.rdmsr(0x800 + (reg >> 4))
	} else {
		return cpu.mmio_in(&u32(self.base_addr + reg))
	}
}

fn (self Lapic) write(reg u32, val u64) {
	if self.x2apic_mode {
		cpu.wrmsr(0x800 + (reg >> 4), val)
	} else {
		cpu.mmio_out(&u32(self.base_addr + reg), u32(val))
	}
}

fn (mut self Lapic) init() {
	self.x2apic_mode = mp_request.response.flags & 1 != 0

	if self.x2apic_mode {
		log.info(c'Using x2APIC mode!\n')
	} else {
		flags := mem.MappingType.kernel_data.flags()
		kernel_page_table.map_range_to(lapic_addr, 0x1000, flags)
		self.base_addr = mem.phys_to_virt(lapic_addr)
		log.info(c'Using xAPIC mode! Base address: %#p\n', self.base_addr)
	}

	self.write(lapic_reg_timer, u64(idt.InterruptIndex.timer))
	self.write(lapic_reg_spurious, 0xff | 1 << 8)
	self.write(lapic_reg_timer_div, 0b1011)

	begin_time := hpet.elapsed()
	self.write(lapic_reg_timer_initcnt, ~u32(0))
	for hpet.elapsed() - begin_time < 1000000 {}
	lapic_ticks := ~u32(0) - self.read(lapic_reg_timer_curcnt)

	calibrated_timer_initial := lapic_ticks * 1000 / lapic_timer_freq_hz
	log.info(c'Calibrated LAPIC timer: %d ticks per second\n', calibrated_timer_initial)

	self.write(lapic_reg_timer, self.read(lapic_reg_timer) | 1 << 17)
	self.write(lapic_reg_timer_initcnt, calibrated_timer_initial)
}
