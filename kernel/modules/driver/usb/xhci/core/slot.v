module core

import bus { UsbDevice }
import utils { Oneshot }

pub struct Slot {
pub mut:
	id           u8
	active       bool
	port_id      int
	speed        u32
	usb_device   &UsbDevice = unsafe { nil }
	out_ctx_virt &u8        = unsafe { nil }
	out_ctx_phys u64
	rings        [32]TransferRing
	ctrl_chan    Oneshot[Trb]
}
