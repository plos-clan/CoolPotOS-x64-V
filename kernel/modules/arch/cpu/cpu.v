module cpu

pub fn hlt() {
	asm volatile amd64 {
		hlt
	}
}

pub fn read_cr2() u64 {
	mut ret := u64(0)
	asm volatile amd64 {
		mov ret, cr2
		; =r (ret)
		; ; memory
	}
	return ret
}
