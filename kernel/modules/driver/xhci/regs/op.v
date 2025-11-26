module regs

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

const op_usbcmd_off = 0x00
const op_usbsts_off = 0x04
const op_dnctrl_off = 0x14
const op_crcr_off = 0x18
const op_dcbaap_off = 0x30
const op_config_off = 0x38

pub struct Operational {
pub:
	base_addr usize
}

pub fn Operational.new(base_addr usize) Operational {
	return Operational{
		base_addr: base_addr
	}
}

pub fn (self Operational) read_usbcmd() u32 {
	return mmio_in[u32](&u32(self.base_addr + op_usbcmd_off))
}

pub fn (self Operational) read_usbsts() u32 {
	return mmio_in[u32](&u32(self.base_addr + op_usbsts_off))
}

fn (self Operational) write_usbcmd(val u32) {
	mmio_out[u32](&u32(self.base_addr + op_usbcmd_off), val)
}

pub fn (self Operational) write_usbsts(val u32) {
	mmio_out[u32](&u32(self.base_addr + op_usbsts_off), val)
}

pub fn (self Operational) start() {
	val := self.read_usbcmd()
	self.write_usbcmd(val | 1)
}

pub fn (self Operational) stop() {
	val := self.read_usbcmd()
	self.write_usbcmd(val & ~u32(1))
}

pub fn (self Operational) reset() {
	val := self.read_usbcmd()
	self.write_usbcmd(val | 2)
}

pub fn (self Operational) is_running() bool {
	return (self.read_usbcmd() & 1) != 0
}

pub fn (self Operational) is_halted() bool {
	return (self.read_usbsts() & 1) != 0
}

pub fn (self Operational) not_ready() bool {
	return (self.read_usbsts() & (1 << 11)) != 0
}

pub fn (self Operational) set_max_slots_enabled(num u8) {
	val := self.read_config() & ~u32(0xFF)
	self.write_config(val | u32(num))
}

fn (self Operational) read_config() u32 {
	return mmio_in[u32](&u32(self.base_addr + op_config_off))
}

fn (self Operational) write_config(val u32) {
	mmio_out[u32](&u32(self.base_addr + op_config_off), val)
}

pub fn (self Operational) set_dcbaap(phys_addr u64) {
	low := u32(phys_addr & 0xffffffff)
	high := u32(phys_addr >> 32)
	mmio_out[u32](&u32(self.base_addr + op_dcbaap_off), low)
	mmio_out[u32](&u32(self.base_addr + op_dcbaap_off + 4), high)
}

pub fn (self Operational) set_crcr(phys_addr u64) {
	low := u32(phys_addr & 0xffffffff) | 1
	high := u32(phys_addr >> 32)
	mmio_out[u32](&u32(self.base_addr + op_crcr_off), low)
	mmio_out[u32](&u32(self.base_addr + op_crcr_off + 4), high)
}
