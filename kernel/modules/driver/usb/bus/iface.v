module bus

import defs {
	EndpointDescriptor,
	InterfaceDescriptor,
	SsEndpointCompanionDescriptor,
}
import utils { Vec }

pub struct UsbEndpoint {
pub mut:
	desc    EndpointDescriptor
	ss_desc ?SsEndpointCompanionDescriptor
}

pub struct UsbInterface {
pub mut:
	device    &UsbDevice = unsafe { nil }
	desc      InterfaceDescriptor
	driver    ?UsbDriver
	endpoints Vec[UsbEndpoint]
}

pub fn (self &UsbInterface) matches(class u8, sub u8, proto u8) bool {
	desc := &self.desc
	return (class == 0xff || desc.interface_class == class)
		&& (sub == 0xff || desc.interface_subclass == sub)
		&& (proto == 0xff || desc.interface_protocol == proto)
}

pub fn (self &UsbInterface) find_endpoint(ep_type u8, is_in bool) ?&UsbEndpoint {
	target_dir := if is_in { defs.req_dir_in } else { 0 }

	for ep in self.endpoints.iter() {
		cur_dir := ep.desc.endpoint_address & defs.req_dir_in
		cur_type := ep.desc.attributes & 0x03

		if cur_dir == target_dir && cur_type == ep_type {
			return unsafe { ep }
		}
	}

	return none
}
