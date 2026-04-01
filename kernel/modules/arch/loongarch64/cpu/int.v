module cpu

const crmd_ie = u64(1 << 2)

pub fn cli() {
	mut mask := crmd_ie
	asm volatile loongarch64 {
		csrxchg r0, mask, 0
		; ; r (mask)
	}
}

pub fn sti() {
	mut mask := crmd_ie
	asm volatile loongarch64 {
		csrxchg mask, mask, 0
		; +r (mask)
	}
}

pub fn hcf() {
	for {
		asm volatile loongarch64 {
			idle 0
		}
	}
}

pub fn spin_hint() {
	asm volatile loongarch64 {
		nop
		; ; ; memory
	}
}

pub fn interrupt_state() bool {
	return read_crmd() & crmd_ie != 0
}
