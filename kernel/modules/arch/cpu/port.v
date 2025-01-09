module cpu

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
