module regs

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

pub struct Doorbell {
	base_addr usize
}

pub fn Doorbell.new(base_addr usize) Doorbell {
	return Doorbell{
		base_addr: base_addr
	}
}

pub fn (self Doorbell) ring(target u8, stream_id u16) {
	addr := self.base_addr + usize(target) * 4
	val := (u32(stream_id) << 16) | u32(target)
	mmio_out[u32](&u32(addr), val)
}
