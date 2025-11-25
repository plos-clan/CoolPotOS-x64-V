module xhci

import core
import mem
import log

fn init_controller(base_addr usize) {
	mut xhci := core.Xhci.new(base_addr)
	print_xhci_info(xhci)

	if !xhci.reset_controller() {
		log.error(c'xHCI initialization failed')
		return
	}

	max_slots := xhci.cap.max_slots()
	xhci.op.set_max_slots_enabled(max_slots)

	xhci.setup_dcbaa(max_slots)
	xhci.setup_command_ring()
	xhci.setup_interrupter()

	xhci.op.start()
	log.info(c'xHCI Initialized successfully')

	xhci.test_command_ring() or { return }
	xhci.check_ports()
}

pub fn init() {
	for i in 0 .. pci_devices.len {
		device := pci_devices.get(i) or { continue }

		if device.device_type != .usb_controller {
			continue
		}

		bar := device.bars[0]
		flags := mem.MappingType.kernel_data.flags()
		kernel_page_table.map_range_to(bar.address, bar.size, flags)

		init_controller(mem.phys_to_virt(bar.address))
	}
}

fn print_xhci_info(xhci core.Xhci) {
	version := xhci.cap.version()
	max_slots := xhci.cap.max_slots()
	max_ports := xhci.cap.max_ports()

	log.debug(c'xHCI Version: %x.%x', version >> 8, version & 0xff)
	log.debug(c'Max Slots: %d, Max Ports: %d', max_slots, max_ports)

	if xhci.cap.address_64bit() {
		log.debug(c'Controller supports 64-bit address')
	}
}
