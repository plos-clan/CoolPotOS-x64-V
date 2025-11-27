module core

pub const desc_device = 1
pub const desc_configuration = 2
pub const desc_string = 3
pub const desc_interface = 4
pub const desc_endpoint = 5
pub const desc_hid = 0x21

pub const req_get_status = 0
pub const req_clear_feature = 1
pub const req_set_feature = 3
pub const req_set_address = 5
pub const req_get_descriptor = 6
pub const req_set_descriptor = 7
pub const req_get_configuration = 8
pub const req_set_configuration = 9

@[packed]
pub struct SetupPacket {
pub mut:
	request_type u8
	request      u8
	value        u16
	index        u16
	length       u16
}

@[packed]
pub struct DeviceDescriptor {
pub:
	length             u8
	descriptor_type    u8
	bcd_usb            u16
	device_class       u8
	device_subclass    u8
	device_protocol    u8
	max_packet_size_0  u8
	id_vendor          u16
	id_product         u16
	bcd_device         u16
	i_manufacturer     u8
	i_product          u8
	i_serial_number    u8
	num_configurations u8
}

@[packed]
pub struct ConfigurationDescriptor {
pub:
	length              u8
	descriptor_type     u8
	total_length        u16
	num_interfaces      u8
	configuration_value u8
	configuration_str   u8
	attributes          u8
	max_power           u8
}

@[packed]
pub struct InterfaceDescriptor {
pub:
	length             u8
	descriptor_type    u8
	interface_number   u8
	alternate_setting  u8
	num_endpoints      u8
	interface_class    u8
	interface_subclass u8
	interface_protocol u8
	interface_str      u8
}

@[packed]
pub struct EndpointDescriptor {
pub:
	length           u8
	descriptor_type  u8
	endpoint_address u8
	attributes       u8
	max_packet_size  u16
	interval         u8
}
