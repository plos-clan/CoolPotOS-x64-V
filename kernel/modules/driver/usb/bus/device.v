module bus

import defs { DeviceDescriptor }
import utils { Vec }

pub struct UsbDevice {
pub mut:
	host       HostController
	slot_id    u8
	port_id    int
	speed      u32
	desc       DeviceDescriptor
	interfaces Vec[UsbInterface]
	ep_map     UsbEndpointMap
}

pub fn (mut dev UsbDevice) free() {
	dev.interfaces.free()
	C.free(dev)
}

@[params]
pub struct UsbDeviceConfig {
pub:
	host    HostController
	slot_id u8
	port_id int
	speed   u32
}

pub fn UsbDevice.new(cfg UsbDeviceConfig) &UsbDevice {
	ptr := C.malloc(sizeof(UsbDevice))
	C.memset(ptr, 0, sizeof(UsbDevice))

	mut dev := unsafe { &UsbDevice(ptr) }

	dev.host = cfg.host
	dev.slot_id = cfg.slot_id
	dev.port_id = cfg.port_id
	dev.speed = cfg.speed

	return dev
}

pub struct UsbEndpointMap {
mut:
	indices [32]?u8
}

pub fn (self UsbEndpointMap) get(ep_addr u8) ?u8 {
	idx := UsbEndpointMap.index_of(ep_addr)
	return self.indices[idx]
}

pub fn (mut self UsbEndpointMap) set(ep_addr u8, iface_idx u8) {
	idx := UsbEndpointMap.index_of(ep_addr)
	self.indices[idx] = iface_idx
}

fn UsbEndpointMap.index_of(ep_addr u8) u8 {
	ep_num := ep_addr & 0x0f
	is_in := (ep_addr & defs.req_dir_in) != 0
	return if is_in { ep_num + 16 } else { ep_num }
}
