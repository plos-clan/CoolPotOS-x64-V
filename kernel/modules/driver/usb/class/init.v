module class

import hid
import unet

pub fn init() {
	usb_drivers.push(hid.probe_kbd)
	usb_drivers.push(hid.probe_mouse)
	usb_drivers.push(unet.probe_rndis)
}
