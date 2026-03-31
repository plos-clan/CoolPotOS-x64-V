module pcie

import arch.amd64.idt { IrqHandler }
import log

pub enum IrqType {
	intx
	msi
	msix
}

pub struct PciInterrupt {
pub mut:
	irq_type     IrqType
	base_addr    u64
	cap_offset   u8
	pin          u8
	line         u8
	table_bar    u8
	table_offset u32
	table_size   u32
}

pub fn PciInterrupt.resolve(header EndpointHeader) ?PciInterrupt {
	mut intr := PciInterrupt{
		base_addr: header.header.base_addr
	}
	mut iter := header.capabilities()
	mut msi_offset := u8(0)

	for {
		cap := iter.next() or { break }
		if cap.id == pci_cap_id_msix {
			msix := MsixCapability.from(&cap) or { continue }
			intr.irq_type = .msix
			intr.cap_offset = msix.offset
			intr.table_bar = msix.table_bar()
			intr.table_offset = msix.table_offset()
			intr.table_size = msix.table_size()
			return intr
		}
		if cap.id == pci_cap_id_msi {
			msi_offset = cap.offset
		}
	}

	if msi_offset > 0 {
		intr.irq_type = .msi
		intr.cap_offset = msi_offset
		return intr
	}

	pin := header.header.interrupt_pin()
	if pin > 0 {
		intr.irq_type = .intx
		intr.pin = pin
		intr.line = header.header.interrupt_line()
		return intr
	}

	return none
}

pub fn (self PciInterrupt) enable() {
	match self.irq_type {
		.msi {
			cap := MsiCapability{self.base_addr, self.cap_offset}
			cap.set_enabled(true)
		}
		.msix {
			cap := MsixCapability{self.base_addr, self.cap_offset}
			cap.set_enabled(true)
		}
		.intx {
			header := PciHeader{self.base_addr}
			header.update_command(pci_cmd_intx_disable, false)
		}
	}
}

pub fn (self PciInterrupt) register(handler IrqHandler, bars [6]PciBar, index u32) ?u8 {
	vector := vector_allocator.alloc(handler) or {
		log.error(c'Failed to allocate IRQ vector')
		return none
	}

	msg_addr := u64(0xfee00000) | (lapic.id() << 12)

	match self.irq_type {
		.msix {
			table := MsiXTable.new(bars[self.table_bar], self.table_offset, self.table_size)?
			entry := table.entry(index)?
			entry.write(msg_addr, u32(vector), false)
			log.info(c'PCI MSI-X configured (vector: %#x)', vector)
		}
		.msi {
			cap := MsiCapability{self.base_addr, self.cap_offset}
			cap.set_address_data(msg_addr, u16(vector))
			log.info(c'PCI MSI configured (vector: %#x)', vector)
		}
		.intx {
			if index > 0 {
				log.error(c'INTx does not support multiple vectors')
				return none
			}
			ioapic.add_entry(vector, u32(self.line))
			log.info(c'PCI INTx configured (line: %d, vector: %#x)', self.line, vector)
		}
	}

	self.enable()
	return vector
}
