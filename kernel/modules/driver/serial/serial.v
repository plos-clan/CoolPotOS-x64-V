@[has_globals]
module serial

$if amd64 {
	import arch.amd64.cpu { port_in, port_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

$if amd64 {
	const serial_port = u16(0x3f8)

	pub fn init() {
		port_out[u8](serial_port + 1, 0x00)
		port_out[u8](serial_port + 3, 0x80)
		port_out[u8](serial_port + 0, 0x03)
		port_out[u8](serial_port + 1, 0x00)
		port_out[u8](serial_port + 3, 0x03)
		port_out[u8](serial_port + 2, 0xc7)
		port_out[u8](serial_port + 4, 0x0b)
		port_out[u8](serial_port + 4, 0x1e)
		port_out[u8](serial_port + 0, 0xae)

		if port_in[u8](serial_port + 0) != 0xae {
			return
		}

		port_out[u8](serial_port + 4, 0x0f)
	}

	pub fn write(s &u8) {
		unsafe {
			for i := 0; s[i] != 0; i++ {
				for port_in[u8](serial_port + 5) & 0x20 == 0 {}
				port_out[u8](serial_port, s[i])
			}
		}
	}
} $else {
	pub fn init() {
		mmio_out[u8](&u8(uart_addr + 1), 0x00)
		mmio_out[u8](&u8(uart_addr + 3), 0x80)
		mmio_out[u8](&u8(uart_addr + 0), 0x03)
		mmio_out[u8](&u8(uart_addr + 1), 0x00)
		mmio_out[u8](&u8(uart_addr + 3), 0x03)
		mmio_out[u8](&u8(uart_addr + 2), 0xc7)
		mmio_out[u8](&u8(uart_addr + 4), 0x0b)
		mmio_out[u8](&u8(uart_addr + 4), 0x1e)
		mmio_out[u8](&u8(uart_addr + 0), 0xae)

		if mmio_in[u8](&u8(uart_addr + 0)) != 0xae {
			return
		}

		mmio_out[u8](&u8(uart_addr + 4), 0x0f)
		serial_init = true
	}

	pub fn write(s &u8) {
		if !serial_init {
			return
		}

		unsafe {
			for i := 0; s[i] != 0; i++ {
				for mmio_in[u8](&u8(uart_addr + 5)) & 0x20 == 0 {}
				mmio_out[u8](&u8(uart_addr), s[i])
			}
		}
	}
}
