module bus

import defs {
	EndpointDescriptor,
	SetupPacket,
}
import utils { Vec }

@[params]
pub struct ControlTransferArgs {
pub mut:
	slot_id     u8
	setup       SetupPacket
	buffer_phys u64
}

@[params]
pub struct GeneralTransferArgs {
pub mut:
	slot_id     u8
	ep_addr     u8
	buffer_phys u64
	length      u32
}

pub interface HostController {
mut:
	configure_endpoints(slot_id u8, endpoints &Vec[EndpointDescriptor]) ?
	submit_control(args ControlTransferArgs) ?
	submit_transfer(args GeneralTransferArgs) ?
}

pub fn (mut dev UsbDevice) submit_control(args ControlTransferArgs) ? {
	mut final_args := args
	final_args.slot_id = dev.slot_id
	dev.host.submit_control(final_args)?
}

pub fn (mut dev UsbDevice) submit_transfer(args GeneralTransferArgs) ? {
	mut final_args := args
	final_args.slot_id = dev.slot_id
	dev.host.submit_transfer(final_args)?
}

pub fn (mut dev UsbDevice) dispatch_completion(ep_addr u8, status int, len u32) {
	if iface_idx := dev.ep_map.get(ep_addr) {
		iface := dev.interfaces.get(iface_idx)

		if mut driver := iface.driver {
			driver.handle_completion(ep_addr, status, len)
		}
	}
}
