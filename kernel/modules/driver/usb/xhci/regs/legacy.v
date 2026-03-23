module regs

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

const usblegsup_bios_owned_off = 0x02
const usblegsup_os_owned_off = 0x03
const usblegctlsts_off = 0x04
const usblegctlsts_disable_smi_mask = u32((1 << 0) | (1 << 4) | (7 << 13))
const usblegctlsts_clear_status_mask = u32(7 << 29)

pub struct LegacySupport {
pub:
	base_addr usize
}

pub fn LegacySupport.new(base_addr usize) LegacySupport {
	return LegacySupport{
		base_addr: base_addr
	}
}

pub fn (self LegacySupport) bios_owned() bool {
	return mmio_in[u8](self.base_addr + usblegsup_bios_owned_off) != 0
}

pub fn (self LegacySupport) request_os_ownership() {
	mmio_out[u8](self.base_addr + usblegsup_os_owned_off, 1)
}

pub fn (self LegacySupport) sanitize_smi() {
	val := self.read_usblegctlsts()
	sanitized := (val & ~usblegctlsts_disable_smi_mask) | usblegctlsts_clear_status_mask
	self.write_usblegctlsts(sanitized)
}

fn (self LegacySupport) read_usblegctlsts() u32 {
	return mmio_in[u32](self.base_addr + usblegctlsts_off)
}

fn (self LegacySupport) write_usblegctlsts(val u32) {
	mmio_out[u32](self.base_addr + usblegctlsts_off, val)
}
