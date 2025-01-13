module apic

import cpu
import mem
import idt

const ioapic_reg_table_base = 0x10

pub enum IrqVector {
	keyboard   = 1
	mouse      = 12
	hpet_timer = 20
}

struct IoApic {
mut:
	base_addr u64
}

fn (self IoApic) read(reg u32) u32 {
	cpu.mmio_out(&u32(self.base_addr), reg)
	return cpu.mmio_in(&u32(self.base_addr + 0x10))
}

fn (self IoApic) write(reg u32, value u32) {
	cpu.mmio_out(&u32(self.base_addr), reg)
	cpu.mmio_out(&u32(self.base_addr + 0x10), value)
}

fn (self IoApic) add_entry(vector u8, irq u32) {
	ioredtbl := ioapic_reg_table_base + irq * 2
	redirect := u64(vector) | lapic.id() << 56

	self.write(ioredtbl, u32(redirect))
	self.write(ioredtbl + 1, u32(redirect >> 32))
}

fn (mut self IoApic) init() {
	flags := mem.MappingType.kernel_data.flags()
	kernel_page_table.map_range_to(ioapic_addr, 0x1000, flags)
	self.base_addr = mem.phys_to_virt(ioapic_addr)

	self.add_entry(u8(idt.InterruptIndex.keyboard), u8(IrqVector.keyboard))
	self.add_entry(u8(idt.InterruptIndex.mouse), u8(IrqVector.mouse))
	self.add_entry(u8(idt.InterruptIndex.hpet_timer), u8(IrqVector.hpet_timer))
}
