module serial

import arch.io { port_in, port_out }

const serial_port = u16(0x3f8)

pub fn init() {
	port_out[u8]((serial_port + 1), 0x00)
	port_out[u8]((serial_port + 3), 0x80)
	port_out[u8]((serial_port + 0), 0x03)
	port_out[u8]((serial_port + 1), 0x00)
	port_out[u8]((serial_port + 3), 0x03)
	port_out[u8]((serial_port + 2), 0xC7)
	port_out[u8]((serial_port + 4), 0x0B)
	port_out[u8]((serial_port + 4), 0x1E)
	port_out[u8]((serial_port + 0), 0xAE)

	if port_in[u8]((serial_port + 0)) != 0xAE {
		return
	}

	port_out[u8]((serial_port + 4), 0x0F)
}

pub fn write(s &char) {
	s_ptr := charptr(s)
	for *s_ptr != 0 {
		for port_in[u8]((serial_port + 5)) & 0x20 == 0 {}
		port_out[u8](serial_port, *s_ptr)
		unsafe { s_ptr++ }
	}
}
