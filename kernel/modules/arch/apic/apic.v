module apic

import arch.cpu

__global (
	lapic Lapic
	ioapic IoApic
)

pub fn init() {
	disable_pic()
	lapic.init()
	ioapic.init()
	cpu.sti()
}

fn disable_pic() {
	cpu.port_out[u8](0x21, 0xff)
	cpu.port_out[u8](0xa1, 0xff)
}
