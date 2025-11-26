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
		param_low:  0
		param_high: 0
		status:     0
		control:    u32(trb_no_op_cmd) << 10
	}
}

pub fn Trb.new_normal(buffer u64, len u32) Trb {
	return Trb{
		param_low:  u32(buffer & 0xffffffff)
		param_high: u32(buffer >> 32)
		status:     len
		control:    (u32(trb_normal) << 10) | (1 << 5) | (1 << 2)
	}
}

pub fn Trb.new_enable_slot() Trb {
	return Trb{
		param_low:  0
		param_high: 0
		status:     0
		control:    u32(trb_enable_slot) << 10
	}
}

pub fn Trb.new_setup_stage(plow u32, phigh u32, trt u32) Trb {
	return Trb{
		param_low:  plow
		param_high: phigh
		status:     8
		control:    (u32(trb_setup_stage) << 10) | (1 << 6) | (trt << 16)
	}
}

pub fn Trb.new_data_stage(buffer u64, len u32, dir_in bool) Trb {
	dir_bit := if dir_in { u32(1) << 16 } else { u32(0) }
	return Trb{
		param_low:  u32(buffer & 0xffffffff)
		param_high: u32(buffer >> 32)
		status:     len
		control:    (u32(trb_data_stage) << 10) | dir_bit | (1 << 4)
	}
}

pub fn Trb.new_status_stage(dir_in bool) Trb {
	dir_bit := if dir_in { u32(1) << 16 } else { u32(0) }
	return Trb{
		control: (u32(trb_status_stage) << 10) | dir_bit | (1 << 5)
	}
}

@[packed]
pub struct SlotContext {
pub mut:
	info1 u32
	info2 u32
	tt_id u32
	state u32
	rsvd  [4]u32
}

pub fn (mut s SlotContext) set_entries(count u32) {
	s.info1 |= (count & 0x1f) << 27
}

pub fn (mut s SlotContext) set_root_hub_port(port u32) {
	s.info2 |= (port & 0xff) << 16
}

pub fn (mut s SlotContext) set_speed(speed u32) {
	s.info1 |= (speed & 0xf) << 20
}

pub fn (mut s SlotContext) set_route_string(route u32) {
	s.info1 |= (route & 0xfffff)
}

@[packed]
pub struct EndpointContext {
pub mut:
	info1           u32
	info2           u32
	tr_dequeue_low  u32
	tr_dequeue_high u32
	avg_tr_len      u32
	rsvd            [3]u32
}

pub fn (mut e EndpointContext) set_ep_type(val u32) {
	e.info1 |= (val & 0x7) << 3
}

pub fn (mut e EndpointContext) set_interval(val u32) {
	e.info1 |= (val & 0xff) << 16
}

pub fn (mut e EndpointContext) set_max_packet_size(size u32) {
	e.info2 |= (size & 0xffff) << 16
}

pub fn (mut e EndpointContext) set_error_count(count u32) {
	e.info2 |= (count & 0x3) << 1
}

pub fn (mut e EndpointContext) set_max_burst_size(size u32) {
	e.info2 |= (size & 0xff) << 8
}

pub fn (mut e EndpointContext) set_average_trb_len(len u32) {
	e.avg_tr_len |= (len & 0xffff)
}

pub fn (mut e EndpointContext) set_max_esit_payload(size u32) {
	e.avg_tr_len |= (size & 0xffff) << 16
}

pub fn (mut e EndpointContext) set_dequeue_ptr(ptr u64) {
	e.tr_dequeue_low = u32(ptr) | 1
	e.tr_dequeue_high = u32(ptr >> 32)
}

@[packed]
pub struct InputControlContext {
pub mut:
	drop_flags u32
	add_flags  u32
	rsvd       [6]u32
}

@[packed]
pub struct InputContext {
pub mut:
	control InputControlContext
	slot    SlotContext
	ep0     EndpointContext
	eps     [30]EndpointContext
}

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
