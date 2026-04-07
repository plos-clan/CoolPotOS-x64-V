module core

import bus { UsbDevice }
import task.async { Oneshot, Semaphore }

pub struct Slot {
pub mut:
	id           u8
	active       bool
	port_id      int
	speed        u32
	usb_device   &UsbDevice = unsafe { nil }
	out_ctx_virt &u8        = unsafe { nil }
	out_ctx_phys u64
	eps          [32]&Endpoint
}

pub struct Endpoint {
pub mut:
	ring     TransferRing
	sem      Semaphore
	promises [256]Oneshot[Trb]
}

pub fn Endpoint.new() &Endpoint {
	ptr := C.calloc(1, sizeof(Endpoint))
	mut ep := unsafe { &Endpoint(ptr) }
	ep.ring = TransferRing.new()
	ep.sem = Semaphore.new(ep.ring.capacity)
	return ep
}

pub fn (mut self Endpoint) free() {
	if self.ring.phys_addr != 0 {
		self.ring.free()
		self.ring.phys_addr = 0
	}
	C.free(self)
}
