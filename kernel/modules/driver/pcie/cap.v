module pcie

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

pub const pci_cap_id_msi = u8(0x05)
pub const pci_cap_id_msix = u8(0x11)

pub struct PciCapability {
pub:
	id        u8
	base_addr u64
	offset    u8
}

pub struct CapabilityIterator {
	base_addr u64
mut:
	next_ptr u8
}

pub fn (mut iter CapabilityIterator) next() ?PciCapability {
	if iter.next_ptr == 0 {
		return none
	}

	current_ptr := iter.next_ptr & ~u8(3)
	if current_ptr == 0 {
		return none
	}

	cap_reg := mmio_in[u16](iter.base_addr + current_ptr)
	cap_id := u8(cap_reg & 0xff)
	iter.next_ptr = u8(cap_reg >> 8)

	return PciCapability{
		id:        cap_id
		base_addr: iter.base_addr
		offset:    current_ptr
	}
}

pub struct MsiCapability {
pub:
	base_addr u64
	offset    u8
}

pub fn MsiCapability.from(cap &PciCapability) ?MsiCapability {
	if cap.id != pci_cap_id_msi {
		return none
	}
	return MsiCapability{
		base_addr: cap.base_addr
		offset:    cap.offset
	}
}

pub fn (m MsiCapability) set_enabled(enable bool) {
	ctrl_addr := m.base_addr + m.offset + 2
	mut msg_ctrl := mmio_in[u16](ctrl_addr)

	if enable {
		msg_ctrl |= 1
	} else {
		msg_ctrl &= ~u16(1)
	}

	mmio_out[u16](ctrl_addr, msg_ctrl)
}

pub struct MsixCapability {
pub:
	base_addr u64
	offset    u8
}

pub fn MsixCapability.from(cap &PciCapability) ?MsixCapability {
	if cap.id != pci_cap_id_msix {
		return none
	}
	return MsixCapability{
		base_addr: cap.base_addr
		offset:    cap.offset
	}
}

pub fn (m MsixCapability) set_enabled(enable bool) {
	ctrl_addr := m.base_addr + m.offset + 2
	mut msg_ctrl := mmio_in[u16](ctrl_addr)

	if enable {
		msg_ctrl |= (1 << 15)
		msg_ctrl &= ~(1 << 14)
	} else {
		msg_ctrl &= ~(1 << 15)
	}

	mmio_out[u16](ctrl_addr, msg_ctrl)
}

pub fn (m MsixCapability) table_size() u32 {
	msg_ctrl := mmio_in[u16](m.base_addr + m.offset + 2)
	return u32(msg_ctrl & 0x7ff) + 1
}

pub fn (m MsixCapability) table_bar() u8 {
	table_offset_reg := mmio_in[u32](m.base_addr + m.offset + 4)
	return u8(table_offset_reg & 0x7)
}

pub fn (m MsixCapability) table_offset() u32 {
	table_offset_reg := mmio_in[u32](m.base_addr + m.offset + 4)
	return table_offset_reg & ~u32(0x7)
}
