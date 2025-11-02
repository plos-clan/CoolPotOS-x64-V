module mouse

import log
import arch.cpu { port_in, port_out }

const max_port_wait_count = 2000000

pub struct MousePorts {
	command u16 = 0x64
	data    u16 = 0x60
}

fn (ports MousePorts) read() ?u8 {
	ports.wait_read()?
	return port_in[u8](ports.data)
}

fn (ports MousePorts) send(cmd u8) ? {
	ports.wait_write()?
	port_out[u8](ports.command, 0xd4)
	ports.wait_write()?
	port_out[u8](ports.data, cmd)
	if ports.read()? != 0xfa {
		return none
	}
}

fn (ports MousePorts) wait_read() ? {
	for i := 0; i < max_port_wait_count; i++ {
	  status := port_in[u8](ports.command)
	  log.info(c"read status: %#x\n", status)
		if (status & 0x1) != 0 { return }
	}
	return none
}

fn (ports MousePorts) wait_write() ? {
	for i := 0; i < max_port_wait_count; i++ {
		if (port_in[u8](ports.command) & 0x2) == 0 {
			return
		}
	}
	return none
}
