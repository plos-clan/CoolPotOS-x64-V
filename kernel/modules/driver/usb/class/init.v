module class

import hid

pub fn init() {
	usb_drivers.push(hid.probe_kbd)
	usb_drivers.push(hid.probe_mouse)
}
