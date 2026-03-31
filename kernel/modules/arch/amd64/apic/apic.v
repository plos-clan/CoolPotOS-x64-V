@[has_globals]
module apic

import cpu

__global (
	lapic  Lapic
	ioapic IoApic
)

pub fn init() {
	disable_pic()
	lapic.init()
	ioapic.init()
	hpet.init()
	lapic.init_timer()
}

fn disable_pic() {
	cpu.port_out[u8](0x21, 0xff)
	cpu.port_out[u8](0xa1, 0xff)
}
