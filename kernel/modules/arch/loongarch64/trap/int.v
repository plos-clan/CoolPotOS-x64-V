module trap

import cpu
import log
import driver.term

const csr_estat_is_ti = 1 << 11

pub fn init() {
	cpu.write_eentry(u64(trap_wrapper))

	cpu.write_tcfg(10000000 | 0b11)
	cpu.write_crmd(cpu.read_crmd() | 0b100)
}

@[export: 'trap_handler']
fn trap_handler() {
	estat := cpu.read_estat()
	ecode := (estat >> 16) & 0x3f

	if ecode == 0 {
		if (estat & csr_estat_is_ti) != 0 {
			term.update()
			cpu.write_ticlr(1)
		} else {
			log.warn(c'Unknown interrupt! Estat: %#x', estat)
		}
	} else {
		era := cpu.read_era()
		badv := cpu.read_badv()

		log.error(c'Unhandled Exception! Ecode: %d', ecode)
		log.error(c'ERA (PC): %#lx BADV: %#lx', era, badv)

		for {
			cpu.hcf()
		}
	}
}
