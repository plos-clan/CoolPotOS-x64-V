module bus

import log

fn (mut dev UsbDevice) match_drivers() {
	if usb_drivers.len == 0 {
		log.warn(c'No USB drivers registered')
		return
	}

	for mut iface in dev.interfaces.iter() {
		if iface.driver != none {
			continue
		}

		for ptr in usb_drivers.iter() {
			probe_fn := *ptr
			if driver := probe_fn(iface) {
				iface.driver = driver
				log.info(c'Interface bound to driver successfully')
				break
			}
		}
	}
}
