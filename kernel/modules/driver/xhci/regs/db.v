module regs

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub struct Doorbell {
	base_addr usize
}

pub fn Doorbell.new(base_addr usize) Doorbell {
	return Doorbell{
		base_addr: base_addr
	}
}

pub fn (self Doorbell) ring(slot_id u8, dci u32) {
	addr := self.base_addr + usize(slot_id) * 4
	cpu.mmio_out[u32](&u32(addr), dci)
}
