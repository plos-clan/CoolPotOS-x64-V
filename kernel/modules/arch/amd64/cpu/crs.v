module cpu

pub fn read_cr2() u64 {
	mut ret := u64(0)
	asm volatile amd64 {
		mov ret, cr2
		; =r (ret)
		; ; memory
	}
	return ret
}

pub fn read_cr3() u64 {
	mut ret := u64(0)
	asm volatile amd64 {
		mov ret, cr3
		; =r (ret)
		; ; memory
	}
	return ret
}

pub fn write_cr3(value u64) {
	asm volatile amd64 {
		mov cr3, value
		; ; r (value)
		; memory
	}
}
