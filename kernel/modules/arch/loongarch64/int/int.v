module int

import cpu

pub fn init() {
  cpu.write_eentry(u64(trap_handler))
}

pub fn trap_handler() {
  for {
	  asm volatile loongarch64 { idle 0 }
	}
}
