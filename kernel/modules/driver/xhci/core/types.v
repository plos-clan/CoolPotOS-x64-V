module core

@[packed]
pub struct ErstEntry {
pub mut:
	base_addr u64
	size      u32
	reserved  u32
}

pub const trb_normal = 1
pub const trb_setup_stage = 2
pub const trb_data_stage = 3
pub const trb_status_stage = 4
pub const trb_link = 6
pub const trb_enable_slot = 9
pub const trb_address_device = 11
pub const trb_configure_endpoint = 12
pub const trb_no_op_cmd = 23
pub const trb_cmd_completion = 33
pub const trb_port_status_change = 34

@[packed]
pub struct Trb {
pub mut:
	param_low  u32
	param_high u32
	status     u32
	control    u32
}

pub fn Trb.new_no_op_cmd() Trb {
	return Trb{
		param_low:  0
		param_high: 0
		status:     0
		control:    u32(trb_no_op_cmd) << 10
	}
}

pub fn (t Trb) get_type() u32 {
	return (t.control >> 10) & 0x3f
}

pub fn (t Trb) completion_code() u32 {
	return (t.status >> 24) & 0xff
}
