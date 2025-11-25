module regs

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

const ir_iman_off = 0x00
const ir_imod_off = 0x04
const ir_erstsz_off = 0x08
const ir_erstba_off = 0x10
const ir_erdp_off = 0x18

pub struct Interrupter {
pub:
	base_addr usize
}

pub fn Interrupter.new(rt_base usize, index int) Interrupter {
	return Interrupter{
		base_addr: rt_base + 0x20 + usize(index * 32)
	}
}

pub fn (self Interrupter) set_erstsz(size u32) {
	mmio_out[u32](&u32(self.base_addr + ir_erstsz_off), size)
}

pub fn (self Interrupter) set_erstba(phys_addr u64) {
	low := u32(phys_addr & 0xffffffff)
	high := u32(phys_addr >> 32)
	mmio_out[u32](&u32(self.base_addr + ir_erstba_off), low)
	mmio_out[u32](&u32(self.base_addr + ir_erstba_off + 4), high)
}

pub fn (self Interrupter) set_erdp(phys_addr u64) {
	low := u32(phys_addr & 0xffffffff)
	high := u32(phys_addr >> 32)
	mmio_out[u32](&u32(self.base_addr + ir_erdp_off), low)
	mmio_out[u32](&u32(self.base_addr + ir_erdp_off + 4), high)
}

pub fn (self Interrupter) enable() {
	val := mmio_in[u32](&u32(self.base_addr + ir_iman_off))
	mmio_out[u32](&u32(self.base_addr + ir_iman_off), val | 0x3)
}
