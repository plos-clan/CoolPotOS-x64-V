@[has_globals]
module acpi

import log

__global (
	lapic_addr  u32
	ioapic_addr u32
)

@[packed]
struct Madt {
	header     SdtHeader
	lapic_addr u32
	flags      u32
	ptrs_start voidptr
}

@[packed]
struct MadtHeader {
	entry_type u8
	length     u8
}

@[packed]
struct MadtLocalApic {
	header       MadtHeader
	processor_id u8
	apic_id      u8
	flags        u32
}

@[packed]
struct MadtIoApic {
	header   MadtHeader
	apic_id  u8
	reserved u8
	address  u32
	gsib     u32
}

@[packed]
struct MadtIoApicISO {
	header     MadtHeader
	bus_source u8
	irq_source u8
	gsi        u32
	flags      u16
}

fn init_madt(table_addr voidptr) {
	madt := unsafe { &Madt(table_addr) }
	lapic_addr = madt.lapic_addr

	mut cursor := usize(table_addr) + sizeof(Madt)
	end_addr := usize(table_addr) + madt.header.length

	for cursor < end_addr {
		entry := &MadtHeader(cursor)

		if entry.entry_type == 1 {
			ioapic := &MadtIoApic(cursor)
			ioapic_addr = ioapic.address
		}

		cursor += entry.length
	}

	log.debug(c'Local APIC address: %#p', lapic_addr)
	log.debug(c'IO APIC address: %#p', ioapic_addr)
}
