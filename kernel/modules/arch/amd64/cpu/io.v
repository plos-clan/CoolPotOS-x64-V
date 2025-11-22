module cpu

pub fn port_in[T](port u16) T {
	mut ret := T(0)
	asm volatile amd64 {
		in ret, port
		; =a (ret)
		; Nd (port)
	}
	return ret
}

pub fn port_out[T](port u16, value T) {
	asm volatile amd64 {
		out port, value
		; ; a (value)
		  Nd (port)
	}
}

pub fn mmio_in[T](addr &T) T {
	mut ret := T(0)
	asm volatile amd64 {
		mov ret, [addr]
		; =r (ret)
		; r (addr)
		; memory
	}
	return ret
}

pub fn mmio_out[T](addr &T, value T) {
	asm volatile amd64 {
		mov [addr], value
		; ; r (addr)
		  r (value)
		; memory
	}
}
