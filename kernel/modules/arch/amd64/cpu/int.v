module cpu

pub fn cli() {
	asm volatile amd64 {
		cli
	}
}

pub fn sti() {
	asm volatile amd64 {
		sti
	}
}

pub fn hcf() {
	asm volatile amd64 {
		hlt
	}
}

pub fn spin_hint() {
	asm volatile amd64 {
		pause
	}
}

pub fn interrupt_state() bool {
	mut f := u64(0)
	asm volatile amd64 {
		pushfq
		pop f
		; =rm (f)
	}
	return f & (1 << 9) != 0
}
