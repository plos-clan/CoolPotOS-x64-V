module ps2

import arch.amd64.cpu { port_in, port_out }

const command_port = 0x64
const data_port = 0x60
const max_port_wait_count = 20000

pub fn read_data() ?u8 {
	wait_read()?
	return port_in[u8](data_port)
}

pub fn send_command(cmd u8) ? {
	wait_write()?
	port_out[u8](command_port, 0xd4)
	wait_write()?
	port_out[u8](data_port, cmd)
	if read_data()? != 0xfa {
		return none
	}
}

fn wait_read() ? {
	for i := 0; i < max_port_wait_count; i++ {
		if (port_in[u8](command_port) & 0x1) != 0 {
			return
		}
	}
	return none
}

fn wait_write() ? {
	for i := 0; i < max_port_wait_count; i++ {
		if (port_in[u8](command_port) & 0x2) == 0 {
			return
		}
	}
	return none
}
