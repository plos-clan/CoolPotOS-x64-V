module regs

pub const desc_device = 1
pub const desc_configuration = 2
pub const desc_string = 3
pub const desc_interface = 4
pub const desc_endpoint = 5
pub const desc_hid = 0x21

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
