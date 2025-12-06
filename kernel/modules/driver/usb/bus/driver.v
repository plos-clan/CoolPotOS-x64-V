@[has_globals]
module bus

import utils { Vec }

__global (
	usb_drivers Vec[ProbeFn]
)

pub interface UsbDriver {
mut:
	disconnect()
}

pub type ProbeFn = fn (iface &UsbInterface) ?UsbDriver
