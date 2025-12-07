module core

@[packed]
pub struct ErstEntry {
pub mut:
	base_addr u64
	size      u32
	reserved  u32
}

@[packed]
pub struct SlotContext {
pub mut:
	info1    u32
	info2    u32
	tt_id    u32
	state    u32
	reserved [4]u32
}

pub fn SlotContext.from(base usize, ctx_size int) &SlotContext {
	return &SlotContext(&u8(base) + ctx_size)
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
pub struct InputControlContext {
pub mut:
	drop_flags u32
	add_flags  u32
	reserved   [6]u32
}

pub fn InputControlContext.from(base usize) &InputControlContext {
	return &InputControlContext(base)
}

@[packed]
pub struct EndpointContext {
pub mut:
	info1           u32
	info2           u32
	tr_dequeue_low  u32
	tr_dequeue_high u32
	tx_info         u32
	reserved        [3]u32
}

pub fn EndpointContext.from(base usize, dci int, ctx_size int) &EndpointContext {
	offset := (dci + 1) * ctx_size
	return &EndpointContext(&u8(base) + offset)
}

pub fn (mut e EndpointContext) set_mult(val u32) {
	e.info1 |= (val & 0x3) << 8
}

pub fn (mut e EndpointContext) set_interval(val u32) {
	e.info1 |= (val & 0xff) << 16
}

pub fn (mut e EndpointContext) set_ep_type(val u32) {
	e.info2 |= (val & 0x7) << 3
}

pub fn (mut e EndpointContext) set_max_packet_size(size u32) {
	e.info2 |= (size & 0xffff) << 16
}

pub fn (mut e EndpointContext) set_error_count(count u32) {
	e.info2 |= (count & 0x3) << 1
}

pub fn (mut e EndpointContext) set_max_burst(size u32) {
	e.info2 |= (size & 0xff) << 8
}

pub fn (mut e EndpointContext) set_average_trb_len(len u32) {
	e.tx_info |= (len & 0xffff)
}

pub fn (mut e EndpointContext) set_max_esit_payload(size u32) {
	e.tx_info |= (size & 0xffff) << 16
}

pub fn (mut e EndpointContext) set_dequeue_ptr(ptr u64) {
	e.tr_dequeue_low = u32(ptr) | 1
	e.tr_dequeue_high = u32(ptr >> 32)
}
