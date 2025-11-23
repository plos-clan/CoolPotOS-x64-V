module int

import cpu
import log

pub fn init() {
	cpu.write_eentry(u64(trap_handler))

	cpu.write_tcfg(10000000 << 3 | 0b11)
	cpu.write_crmd(cpu.read_crmd() | 0b100)
}

@[irq_handler]
pub fn trap_handler() {
	log.debug(c'Trap handler called')
	cpu.write_ticlr(1)

	for {
		cpu.hcf()
	}
}
