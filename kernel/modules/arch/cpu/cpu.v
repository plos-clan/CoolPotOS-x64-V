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

pub fn port_in[T](port u16) T {
	mut ret := T(0)
	asm volatile amd64 {
		in ret, port
		; =a (ret)
		; Nd (port)
		; memory
	}
	return ret
}

pub fn port_out[T](port u16, value T) {
	asm volatile amd64 {
		out port, value
		; ; a (value)
		  Nd (port)
		; memory
	}
}

pub fn rdmsr(msr u32) u64 {
	mut eax := u32(0)
	mut edx := u32(0)
	asm volatile amd64 {
		rdmsr
		; =a (eax)
		  =d (edx)
		; c (msr)
		; memory
	}
	return (u64(edx) << 32) | eax
}

pub fn wrmsr(msr u32, value u64) {
	eax := u32(value)
	edx := value >> 32
	asm volatile amd64 {
		wrmsr
		; ; a (eax)
		  d (edx)
		  c (msr)
		; memory
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
