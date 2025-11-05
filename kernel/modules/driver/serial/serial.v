module serial

import arch.cpu { port_in, port_out }

const serial_port = u16(0x3f8)

pub fn init() {
	port_out[u8]((serial_port + 1), 0x00)
	port_out[u8]((serial_port + 3), 0x80)
	port_out[u8]((serial_port + 0), 0x03)
	port_out[u8]((serial_port + 1), 0x00)
	port_out[u8]((serial_port + 3), 0x03)
	port_out[u8]((serial_port + 2), 0xc7)
	port_out[u8]((serial_port + 4), 0x0b)
	port_out[u8]((serial_port + 4), 0x1e)
	port_out[u8]((serial_port + 0), 0xae)

	if port_in[u8]((serial_port + 0)) != 0xae {
		return
	}

	port_out[u8]((serial_port + 4), 0x0f)
}

pub fn write(s &u8) {
	unsafe {
    for i := 0; s[i] != 0; i++ {
      for port_in[u8]((serial_port + 5)) & 0x20 == 0 {}
      port_out[u8](serial_port, s[i])
    }
  }
}
