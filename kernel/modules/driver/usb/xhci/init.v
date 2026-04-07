@[has_globals]
module xhci

import core
import mem
import log
import pcie
import utils { Vec }

__global xhci_controllers Vec[&core.Xhci]

fn init_controller(base_addr usize, device &pcie.PciDevice) {
	mut xhci := core.Xhci.new(base_addr)
	print_xhci_info(xhci)

	if !xhci.take_ownership() {
		log.error(c'xHCI BIOS handoff failed')
		return
	}

	if !xhci.reset_controller() {
		log.error(c'xHCI initialization failed')
		return
	}

	max_slots := xhci.cap.max_slots()
	xhci.op.set_max_slots_enabled(max_slots)

	xhci.setup_dcbaa(max_slots)
	xhci.setup_command_ring()
	xhci.setup_interrupter()

	mut intr := device.interrupt or {
		log.error(c'xHCI controller has no interrupt')
		return
	}

	intr.register(xhci, device.bars, 0) or {
		log.error(c'Failed to register xHCI interrupt')
		return
	}

	xhci.op.start()
	log.info(c'xHCI Initialized successfully')

	xhci_controllers.push(xhci)
	executor.spawn(core.xhci_hub_thread, xhci)
}

pub fn init(device &pcie.PciDevice) {
	bar := device.bars[0]
	flags := mem.MappingType.mmio_region.flags()
	kernel_page_table.map_range_to(bar.address, bar.size, flags)
	init_controller(mem.phys_to_virt(bar.address), device)
}

fn print_xhci_info(xhci &core.Xhci) {
	version := xhci.cap.version()
	max_slots := xhci.cap.max_slots()
	max_ports := xhci.cap.max_ports()

	log.debug(c'xHCI Version: %x.%x', version >> 8, version & 0xff)
	log.debug(c'Max Slots: %d, Max Ports: %d', max_slots, max_ports)

	if xhci.cap.address_64bit() {
		log.debug(c'Controller supports 64-bit address')
	}
}
