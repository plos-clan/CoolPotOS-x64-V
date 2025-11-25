module regs

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

pub const port_ccs = 1 << 0
pub const port_ped = 1 << 1
pub const port_pr = 1 << 4
pub const port_pls = 0xf << 5
pub const port_pp = 1 << 9
pub const port_csc = 1 << 17
pub const port_prc = 1 << 21
pub const port_rw1c_mask = 0xfe0000
pub const port_speed_shift = 10
pub const port_speed_mask = 0xf

pub struct Port {
pub:
	id        int
	base_addr usize
}

pub fn Port.new(op_base usize, index int) Port {
	return Port{
		id:        index + 1
		base_addr: op_base + 0x400 + usize(index * 16)
	}
}

pub fn (p Port) is_connected() bool {
	return (p.read_portsc() & port_ccs) != 0
}

pub fn (p Port) is_enabled() bool {
	return (p.read_portsc() & port_ped) != 0
}

pub fn (p Port) has_connect_change() bool {
	return (p.read_portsc() & port_csc) != 0
}

pub fn (p Port) has_reset_change() bool {
	return (p.read_portsc() & port_prc) != 0
}

pub fn (p Port) is_in_reset() bool {
	return (p.read_portsc() & port_pr) != 0
}

pub fn (p Port) speed_id() u32 {
	return (p.read_portsc() >> 10) & 0xf
}

pub fn (self Port) reset() bool {
	status := self.read_portsc()
	if (status & port_ccs) == 0 {
		return false
	}
	self.update_portsc(|val| val | port_pr | port_pp)
	return true
}

fn (self Port) read_portsc() u32 {
	return mmio_in[u32](&u32(self.base_addr))
}

fn (self Port) update_portsc(modify fn (u32) u32) {
	val := self.read_portsc()
	mut safe_val := val & ~u32(port_rw1c_mask)
	new_val := modify(safe_val)
	mmio_out[u32](&u32(self.base_addr), new_val)
}

pub fn (self Port) clear_change_bit(mask u32) {
	val := self.read_portsc()
	write_val := (val & ~u32(port_rw1c_mask)) | mask
	mmio_out[u32](&u32(self.base_addr), write_val)
}
