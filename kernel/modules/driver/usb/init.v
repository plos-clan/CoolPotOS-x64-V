module usb

import class
import log
import xhci

pub fn init() {
	log.info(c'Initializing USB subsystem...')
	class.init()

	for device in pci_devices.iter() {
		if device.device_type != .usb_controller {
			continue
		}

		match device.prog_if {
			0x30 {
				log.info(c'Found xHCI controller')
				xhci.init(device)
			}
			else {
				log.warn(c'Unknown USB interface: %x', device.prog_if)
			}
		}
	}
}
