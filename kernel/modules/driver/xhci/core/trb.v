module core

pub const trb_cycle = 1 << 0
pub const trb_ent   = 1 << 1
pub const trb_isp   = 1 << 2
pub const trb_ns    = 1 << 3
pub const trb_chain = 1 << 4
pub const trb_ioc   = 1 << 5
pub const trb_idt   = 1 << 6

pub const trb_normal = 1
pub const trb_setup_stage = 2
pub const trb_data_stage = 3
pub const trb_status_stage = 4
pub const trb_link = 6
pub const trb_enable_slot = 9
pub const trb_disable_slot = 10
pub const trb_address_device = 11
pub const trb_configure_endpoint = 12
pub const trb_no_op_cmd = 23
pub const trb_transfer_event = 32
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

pub fn (t Trb) get_type() u32 {
	return (t.control >> 10) & 0x3f
}

pub fn (t Trb) completion_code() u32 {
	return (t.status >> 24) & 0xff
}

pub fn (t Trb) slot_id() u8 {
	return u8((t.control >> 24) & 0xff)
}

pub fn Trb.new_no_op_cmd() Trb {
	return Trb{
		control: u32(trb_no_op_cmd) << 10
	}
}

pub fn Trb.new_normal(buffer u64, len u32) Trb {
	return Trb{
		param_low:  u32(buffer)
		param_high: u32(buffer >> 32)
		status:     len
		control:    (u32(trb_normal) << 10) | trb_ioc | trb_isp
	}
}

pub fn Trb.new_enable_slot() Trb {
	return Trb{
		control: u32(trb_enable_slot) << 10
	}
}

pub fn Trb.new_disable_slot(slot_id u8) Trb {
	return Trb{
		control: (u32(trb_disable_slot) << 10) | (u32(slot_id) << 24)
	}
}

pub fn Trb.new_setup_stage(req_low u32, req_high u32, trt u32) Trb {
	return Trb{
		param_low:  req_low
		param_high: req_high
		status:     8
		control:    (u32(trb_setup_stage) << 10) | trb_idt | (trt << 16)
	}
}

pub fn Trb.new_data_stage(buffer u64, len u32, dir_in bool) Trb {
	dir_bit := if dir_in { u32(1) << 16 } else { u32(0) }
	return Trb{
		param_low:  u32(buffer)
		param_high: u32(buffer >> 32)
		status:     len
		control:    (u32(trb_data_stage) << 10) | dir_bit | trb_chain
	}
}

pub fn Trb.new_status_stage(dir_in bool) Trb {
	dir_bit := if dir_in { u32(1) << 16 } else { u32(0) }
	return Trb{
		control: (u32(trb_status_stage) << 10) | dir_bit | trb_ioc
	}
}

pub fn Trb.new_address_device(ctx_ptr u64, slot_id u8) Trb {
	return Trb{
		param_low:  u32(ctx_ptr)
		param_high: u32(ctx_ptr >> 32)
		control:    (u32(trb_address_device) << 10) | (u32(slot_id) << 24)
	}
}

pub fn Trb.new_configure_endpoint(ctx_ptr u64, slot_id u8) Trb {
	return Trb{
		param_low:  u32(ctx_ptr)
		param_high: u32(ctx_ptr >> 32)
		control:    (u32(trb_configure_endpoint) << 10) | (u32(slot_id) << 24)
	}
}
