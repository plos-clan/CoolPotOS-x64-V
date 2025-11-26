@[has_globals]
module serial

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
	import mem
}

const reg_rbr = 0
const reg_thr = 0
const reg_ier = 1
const reg_iir = 2
const reg_fcr = 2
const reg_lcr = 3
const reg_mcr = 4
const reg_lsr = 5

__global (
	serial Serial
)

struct Serial {
mut:
	base_addr u64
	ready     bool
}

pub fn (mut self Serial) init() {
	$if amd64 {
		self.base_addr = 0x3f8
	} $else {
		flags := mem.MappingType.mmio_region.flags()
		kernel_page_table.map_range_to(uart_addr, 0x1000, flags)
		self.base_addr = mem.phys_to_virt(uart_addr)
	}

	self.write_reg(reg_ier, 0x00)
	self.write_reg(reg_lcr, 0x80)
	self.write_reg(reg_thr, 0x03)
	self.write_reg(reg_ier, 0x00)
	self.write_reg(reg_lcr, 0x03)
	self.write_reg(reg_fcr, 0xc7)
	self.write_reg(reg_mcr, 0x0b)
	self.write_reg(reg_mcr, 0x1e)
	self.write_reg(reg_thr, 0xae)

	if self.read_reg(reg_rbr) == 0xae {
		self.write_reg(reg_mcr, 0x0f)
		self.ready = true
	} else {
		self.ready = false
	}
}

pub fn (self Serial) write(s &u8) {
	if !self.ready {
		return
	}

	unsafe {
		for i := 0; s[i] != 0; i++ {
			for self.read_reg(reg_lsr) & 0x20 == 0 {
				cpu.spin_hint()
			}
			self.write_reg(reg_thr, s[i])
		}
	}
}

fn (s &Serial) read_reg(offset u16) u8 {
	$if amd64 {
		return cpu.port_in[u8](u16(s.base_addr) + offset)
	} $else {
		addr := &u8(s.base_addr + u64(offset))
		return cpu.mmio_in[u8](addr)
	}
}

fn (s &Serial) write_reg(offset u16, val u8) {
	$if amd64 {
		cpu.port_out[u8](u16(s.base_addr) + offset, val)
	} $else {
		addr := &u8(s.base_addr + u64(offset))
		cpu.mmio_out[u8](addr, val)
	}
}
