@[has_globals]
module bus

import utils { Vec }

__global (
	usb_drivers Vec[ProbeFn]
)

pub interface UsbDriver {
mut:
	disconnect()
	handle_completion(ep_addr u8, status int, len u32)
}

pub type ProbeFn = fn (iface &UsbInterface) ?UsbDriver
