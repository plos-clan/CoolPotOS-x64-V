module regs

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

pub struct Capability {
pub:
	base_addr usize
}

pub fn Capability.new(base_addr usize) Capability {
	return Capability{
		base_addr: base_addr
	}
}

pub fn (self Capability) length() u8 {
	return mmio_in[u8](self.base_addr)
}

pub fn (self Capability) version() u16 {
	return mmio_in[u16](self.base_addr + 0x02)
}

fn (self Capability) hcsparams1() u32 {
	return mmio_in[u32](self.base_addr + 0x04)
}

fn (self Capability) hcsparams2() u32 {
	return mmio_in[u32](self.base_addr + 0x08)
}

fn (self Capability) hccparams1() u32 {
	return mmio_in[u32](self.base_addr + 0x10)
}

pub fn (self Capability) db_off() u32 {
	return mmio_in[u32](self.base_addr + 0x14) & ~u32(0x3)
}

pub fn (self Capability) rts_off() u32 {
	return mmio_in[u32](self.base_addr + 0x18) & ~u32(0x1f)
}

pub fn (self Capability) max_slots() u8 {
	return u8(self.hcsparams1() & 0xff)
}

pub fn (self Capability) max_ports() u8 {
	return u8(self.hcsparams1() >> 24)
}

pub fn (self Capability) max_interrupters() u32 {
	return (self.hcsparams1() >> 8) & 0x7ff
}

pub fn (self Capability) address_64bit() bool {
	return (self.hccparams1() & 1) != 0
}

pub fn (self Capability) context_64byte() bool {
	return (self.hccparams1() & (1 << 2)) != 0
}

pub fn (self Capability) xecp() u32 {
	return ((self.hccparams1() >> 16) & 0xffff) << 2
}

pub fn (self Capability) max_scratchpad_bufs() u32 {
	high := (self.hcsparams2() >> 21) & 0x1f
	low := (self.hcsparams2() >> 27) & 0x1f
	return (high << 5) | low
}

pub fn (self Capability) legacy_support() ?LegacySupport {
	addr := self.find_ext_cap(1)?
	return LegacySupport.new(addr)
}

pub fn (self Capability) find_ext_cap(target_id u8) ?usize {
	mut off := self.xecp()

	for i := 0; off != 0 && i < 32; i++ {
		addr := self.base_addr + usize(off)
		hdr := mmio_in[u32](addr)

		if (hdr & 0xff) == u32(target_id) {
			return addr
		}
		if (hdr & 0xff00) == 0 {
			break
		}

		off += ((hdr >> 8) & 0xff) << 2
	}

	return none
}
