module pcie

import log

pub struct PciDevice {
pub:
	address     PciAddress
	vendor_id   u16
	device_id   u16
	class_code  u8
	sub_class   u8
	prog_if     u8
	revision    u8
	bars        [6]PciBar
	device_type PciDeviceType
}

pub fn (device &PciDevice) print_info() {
	log.info(
		c'%02x:%02x.%x: %s [%04x:%04x] (rev: %02x)',
		device.address.bus(),
		device.address.device(),
		device.address.function(),
		device.device_type.name(),
		device.vendor_id,
		device.device_id,
		device.revision
	)
}
