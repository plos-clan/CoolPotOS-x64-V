module beep

import arch.cpu { port_in, port_out }

const channel_2_port = 0x42
const command_register_port = 0x43
const speaker_port = 0x61

pub fn play(freq u16, ms u64) {
	div := u16(1193180 / freq)
	
	port_out(command_register_port, u8(0xb6))
	port_out(channel_2_port, u8(div))
	port_out(channel_2_port, u8(div >> 8))

	mut tmp := port_in[u8](speaker_port)

	if tmp & 3 != 3 {
		port_out(speaker_port, tmp | 3)
	}

	hpet.busy_wait(ms * 1000000)

	tmp = port_in[u8](speaker_port) & 0xfc
	port_out(speaker_port, tmp)
}
