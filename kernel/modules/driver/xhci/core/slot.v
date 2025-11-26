module core

pub struct Slot {
pub mut:
	id           u8
	active       bool
	port_id      int
	speed        u32
	out_ctx_virt &u64 = unsafe { nil }
	out_ctx_phys u64
	rings        [32]TransferRing

	rx_buffer_virt &u8 = unsafe { nil }
}
