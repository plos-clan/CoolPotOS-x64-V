module pcie

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

pub const pci_cmd_io_space = u16(1 << 0)
pub const pci_cmd_memory_space = u16(1 << 1)
pub const pci_cmd_bus_master = u16(1 << 2)
pub const pci_cmd_intx_disable = u16(1 << 10)

pub struct PciHeader {
pub:
	base_addr u64
}

pub fn (h PciHeader) vendor_id() u16 {
	return mmio_in[u16](h.base_addr)
}

pub fn (h PciHeader) device_id() u16 {
	return mmio_in[u16](h.base_addr + 0x02)
}

pub fn (h PciHeader) command() u16 {
	return mmio_in[u16](h.base_addr + 0x04)
}

pub fn (h PciHeader) status() u16 {
	return mmio_in[u16](h.base_addr + 0x06)
}

pub fn (h PciHeader) class_code() u8 {
	return mmio_in[u8](h.base_addr + 0x0b)
}

pub fn (h PciHeader) sub_class() u8 {
	return mmio_in[u8](h.base_addr + 0x0a)
}

pub fn (h PciHeader) prog_if() u8 {
	return mmio_in[u8](h.base_addr + 0x09)
}

pub fn (h PciHeader) revision() u8 {
	return mmio_in[u8](h.base_addr + 0x08)
}

pub fn (h PciHeader) header_type() u8 {
	return mmio_in[u8](h.base_addr + 0x0e) & 0x7f
}

pub fn (h PciHeader) interrupt_line() u8 {
	return mmio_in[u8](h.base_addr + 0x3c)
}

pub fn (h PciHeader) interrupt_pin() u8 {
	return mmio_in[u8](h.base_addr + 0x3d)
}

pub fn (h PciHeader) has_capabilities() bool {
	return (h.status() & (1 << 4)) != 0
}

pub fn (h PciHeader) update_command(mask u16, enable bool) {
	cmd_addr := h.base_addr + 0x04
	mut cmd := mmio_in[u16](cmd_addr)
	if enable {
		cmd |= mask
	} else {
		cmd &= ~mask
	}
	mmio_out[u16](cmd_addr, cmd)
}

pub struct EndpointHeader {
pub:
	header PciHeader
}

pub fn (e EndpointHeader) bars() [6]PciBar {
	mut bars := [6]PciBar{}
	mut skip_next := false

	for i in 0 .. 6 {
		if skip_next {
			skip_next = false
			continue
		}

		if bar := PciBar.read(e.header.base_addr, u8(i)) {
			if bar.bar_type == .memory64 {
				skip_next = true
			}
			bars[i] = bar
		}
	}

	return bars
}

pub fn (e EndpointHeader) capabilities() CapabilityIterator {
	if !e.header.has_capabilities() {
		return CapabilityIterator{
			base_addr: e.header.base_addr
			next_ptr:  0
		}
	}
	cap_ptr := mmio_in[u8](e.header.base_addr + 0x34)
	return CapabilityIterator{
		base_addr: e.header.base_addr
		next_ptr:  cap_ptr
	}
}

pub struct BridgeHeader {
pub:
	header PciHeader
}

pub fn (b BridgeHeader) secondary_bus() u8 {
	return mmio_in[u8](b.header.base_addr + 0x19)
}

pub fn (b BridgeHeader) subordinate_bus() u8 {
	return mmio_in[u8](b.header.base_addr + 0x1a)
}
