@[has_globals]
module hpet

import arch.cpu
import arch.apic
import log
import mem

__global (
	hpet Hpet
)

struct Hpet {
mut:
	base_addr    u64
	fms_per_tick u64
}

pub fn (self Hpet) ticks() u64 {
	counter_addr := self.base_addr + 0xf0
	return cpu.mmio_in(&u64(counter_addr))
}

pub fn (self Hpet) elapsed() u64 {
	return self.ticks() * hpet.fms_per_tick / 1_000_000
}

pub fn (self Hpet) estimate(ns u64) u64 {
	return self.ticks() + ns * 1_000_000 / self.fms_per_tick
}

pub fn (self Hpet) busy_wait(ns u64) {
	end := self.estimate(ns)
	for self.ticks() < end {}
}

pub fn (self Hpet) set_timer(value u64) {
	comparator_addr := self.base_addr + 0x108
	cpu.mmio_out(&u64(comparator_addr), value)
}

pub fn init() {
	flags := mem.MappingType.kernel_data.flags()
	kernel_page_table.map_range_to(hpet_addr, 0x1000, flags)
	hpet.base_addr = mem.phys_to_virt(hpet_addr)

	period_addr := hpet.base_addr + 0x4
	hpet.fms_per_tick = cpu.mmio_in(&u32(period_addr))
	log.debug(c'HPET frequency: %d fms per tick\n', hpet.fms_per_tick)

	counter_addr := hpet.base_addr + 0xf0
	cpu.mmio_out(&u64(counter_addr), 0)

	enable_cnf_addr := hpet.base_addr + 0x10
	old_cnf := cpu.mmio_in(&u64(enable_cnf_addr))
	cpu.mmio_out(&u64(enable_cnf_addr), old_cnf | 1)

	timer_config_addr := hpet.base_addr + 0x100
	old_config := cpu.mmio_in(&u64(timer_config_addr))

	route_cap := old_config >> 32
	if (route_cap & (u64(1) << u64(apic.IrqVector.hpet_timer))) == 1 {
		log.warn(c'HPET timer does not support our IRQ vector!\n')
		log.warn(c'Timer route capabilities: %#032b\n', route_cap)
	}

	timer_config := u64(apic.IrqVector.hpet_timer) << 9 | 1 << 2
	cpu.mmio_out(&u64(timer_config_addr), timer_config)
}
