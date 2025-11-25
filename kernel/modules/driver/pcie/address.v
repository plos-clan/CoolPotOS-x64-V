module pcie

$if amd64 {
	import arch.amd64.cpu { mmio_in }
} $else {
	import arch.loongarch64.cpu { mmio_in }
}

import mem
import log

type PciAddress = u32

fn (address PciAddress) segment() u16 {
	return u16((address >> 16) & 0xFFFF)
}

fn (address PciAddress) bus() u8 {
	return u8((address >> 8) & 0xFF)
}

fn (address PciAddress) device() u8 {
	return u8((address >> 3) & 0x1F)
}

fn (address PciAddress) function() u8 {
	return u8(address & 0x7)
}

fn PciAddress.new(seg u16, bus u8, dev u8, func u8) PciAddress {
	return (u32(seg) << 16) | (u32(bus) << 8) | (u32(dev) << 3) | u32(func)
}

fn (address PciAddress) has_multi_funcs() bool {
	base_addr := address.mmio_address()
	header_type := mmio_in[u8](&u8(base_addr + 0x0E))
	return (header_type & 0x80) != 0
}

fn (address PciAddress) mmio_address() u64 {
	segment := address.segment()
	bus := address.bus()
	deivce := u64(address.device())
	function := u64(address.function())

	for i in 0..pci_regions.length {
		entry := pci_regions.at(i)

		if entry.pci_seg_group != segment {
			continue
		}
		if bus < entry.start_bus || bus > entry.end_bus {
			continue
		}

		bus_offset := u64(bus - entry.start_bus)
		offset := (bus_offset << 20) | (deivce << 15) | (function << 12)
		return mem.phys_to_virt(entry.base_addr + offset)
	}

	log.panic(c'PCI Address %#x out of MCFG bounds', address)
}
