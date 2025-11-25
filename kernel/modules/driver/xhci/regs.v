module xhci

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

struct Capability {
	base_addr usize
}

fn Capability.new(base_addr usize) Capability {
	return Capability{
		base_addr: base_addr
	}
}

fn (self Capability) length() u8 {
	return mmio_in[u8](&u8(self.base_addr))
}

fn (self Capability) version() u16 {
	return mmio_in[u16](&u16(self.base_addr + 0x02))
}

fn (self Capability) hcsparams1() u32 {
	return mmio_in[u32](&u32(self.base_addr + 0x04))
}

fn (self Capability) hcsparams2() u32 {
	return mmio_in[u32](&u32(self.base_addr + 0x08))
}

fn (self Capability) hccparams1() u32 {
	return mmio_in[u32](&u32(self.base_addr + 0x10))
}

fn (self Capability) max_slots() u8 {
	return u8(self.hcsparams1() & 0xff)
}

fn (self Capability) max_ports() u8 {
	return u8(self.hcsparams1() >> 24)
}

fn (self Capability) address_64bit() bool {
	return (self.hccparams1() & 1) != 0
}

fn (self Capability) max_scratchpad_bufs() u32 {
	high := (self.hcsparams2() >> 21) & 0x1f
	low := (self.hcsparams2() >> 27) & 0x1f
	return (high << 5) | low
}

struct Operational {
	base_addr usize
}

fn Operational.new(base_addr usize) Operational {
	return Operational{
		base_addr: base_addr
	}
}

const op_usbcmd_off = 0x00
const op_usbsts_off = 0x04
const op_dnctrl_off = 0x14
const op_crcr_off = 0x18
const op_dcbaap_off = 0x30
const op_config_off = 0x38

fn (self Operational) read_usbcmd() u32 {
	return mmio_in[u32](&u32(self.base_addr + op_usbcmd_off))
}

fn (self Operational) write_usbcmd(val u32) {
	mmio_out[u32](&u32(self.base_addr + op_usbcmd_off), val)
}

fn (self Operational) start() {
	val := self.read_usbcmd()
	self.write_usbcmd(val | 1)
}

fn (self Operational) stop() {
	val := self.read_usbcmd()
	self.write_usbcmd(val & ~u32(1))
}

fn (self Operational) reset() {
	val := self.read_usbcmd()
	self.write_usbcmd(val | 2)
}

fn (self Operational) is_running() bool {
	return (self.read_usbcmd() & 1) != 0
}

fn (self Operational) read_usbsts() u32 {
	return mmio_in[u32](&u32(self.base_addr + op_usbsts_off))
}

fn (self Operational) is_halted() bool {
	return (self.read_usbsts() & 1) != 0
}

fn (self Operational) not_ready() bool {
	return (self.read_usbsts() & (1 << 11)) != 0
}

fn (self Operational) has_host_system_error() bool {
	return (self.read_usbsts() & (1 << 2)) != 0
}

fn (self Operational) set_max_slots_enabled(num u8) {
	val := self.read_config() & ~u32(0xFF)
	self.write_config(val | u32(num))
}

fn (self Operational) read_config() u32 {
	return mmio_in[u32](&u32(self.base_addr + op_config_off))
}

fn (self Operational) write_config(val u32) {
	mmio_out[u32](&u32(self.base_addr + op_config_off), val)
}

fn (self Operational) set_dcbaap(phys_addr u64) {
	low := u32(phys_addr & 0xFFFFFFFF)
	high := u32(phys_addr >> 32)
	mmio_out[u32](&u32(self.base_addr + op_dcbaap_off), low)
	mmio_out[u32](&u32(self.base_addr + op_dcbaap_off + 4), high)
}

fn (self Operational) set_crcr(phys_addr u64) {
	low := u32(phys_addr & 0xFFFFFFFF) | 1
	high := u32(phys_addr >> 32)
	mmio_out[u32](&u32(self.base_addr + op_crcr_off), low)
	mmio_out[u32](&u32(self.base_addr + op_crcr_off + 4), high)
}
