@[has_globals]
module bus

import utils { Vec }

__global (
	usb_drivers Vec[ProbeFn]
)

pub enum TransferStatus {
	completed
	short_packet
	stall
	trb_error
	babble
	data_error
	split_error
	timeout
	driver_error
	unknown
}

@[params]
pub struct CompletionEvent {
pub:
	ep_addr       u8
	status        TransferStatus
	actual_length u32
}

pub interface UsbDriver {
mut:
	disconnect()
	handle_completion(event CompletionEvent)
}

pub type ProbeFn = fn (iface &UsbInterface) ?UsbDriver
