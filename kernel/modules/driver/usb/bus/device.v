module bus

import defs {
	DeviceDescriptor,
	EndpointDescriptor,
	InterfaceDescriptor,
}
import utils { Vec }

pub struct UsbDevice {
pub mut:
	host       HostController
	slot_id    u8
	port_id    int
	speed      u32
	desc       DeviceDescriptor
	interfaces Vec[UsbInterface]
	ep_map     [32]?u8
}

pub struct UsbEndpoint {
pub mut:
	desc EndpointDescriptor
}

pub struct UsbInterface {
pub mut:
	device    &UsbDevice = unsafe { nil }
	desc      InterfaceDescriptor
	driver    ?UsbDriver
	endpoints Vec[UsbEndpoint]
}

@[params]
pub struct UsbDeviceConfig {
pub:
	host    HostController
	slot_id u8
	port_id int
	speed   u32
}

pub fn UsbDevice.new(cfg UsbDeviceConfig) UsbDevice {
	return UsbDevice{
		host:    cfg.host
		slot_id: cfg.slot_id
		port_id: cfg.port_id
		speed:   cfg.speed
	}
}
