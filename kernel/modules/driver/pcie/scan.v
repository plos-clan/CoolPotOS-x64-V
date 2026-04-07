module pcie

struct PciScanner {
	segment u16
mut:
	scanned [256]bool
}

fn (mut s PciScanner) try_mark(bus u8) ? {
	if s.scanned[bus] {
		return none
	}
	s.scanned[bus] = true
}

fn (mut s PciScanner) scan_region(start_bus u8, end_bus u8) {
	for bus in int(start_bus) .. int(end_bus) + 1 {
		s.scan_bus(u8(bus))
	}
}

fn (mut s PciScanner) scan_bus(bus u8) {
	s.try_mark(bus) or { return }

	for device in 0 .. 32 {
		address := PciAddress.new(s.segment, bus, device, 0)
		s.scan_function(address) or { continue }

		if address.has_multi_funcs() {
			for function in 1 .. 8 {
				s.scan_function(PciAddress.new(s.segment, bus, device, function))
			}
		}
	}
}

fn (mut s PciScanner) scan_function(address PciAddress) ? {
	header := PciHeader{address.mmio_address()}
	vendor_id := header.vendor_id()

	if vendor_id == 0xffff || vendor_id == 0x0000 {
		return none
	}

	match header.header_type() {
		.endpoint {
			endpoint := EndpointHeader{header}
			base_flags := pci_cmd_memory_space | pci_cmd_io_space | pci_cmd_bus_master
			header.update_command(base_flags, true)
			header.update_command(pci_cmd_intx_disable, true)

			class_code := header.class_code()
			sub_class := header.sub_class()

			device := PciDevice{
				address:     address
				vendor_id:   header.vendor_id()
				device_id:   header.device_id()
				class_code:  class_code
				sub_class:   sub_class
				prog_if:     header.prog_if()
				revision:    header.revision()
				device_type: PciDeviceType.parse(class_code, sub_class)
				bars:        endpoint.bars()
				interrupt:   PciInterrupt.resolve(endpoint)
			}

			device.print_info()
			pci_devices.push(device)
		}
		.pci_pci_bridge {
			bridge := BridgeHeader{header}
			bus := bridge.secondary_bus()

			if bus > bridge.primary_bus() && bus <= bridge.subordinate_bus() {
				s.scan_bus(bus)
			}
		}
		else {}
	}
}
