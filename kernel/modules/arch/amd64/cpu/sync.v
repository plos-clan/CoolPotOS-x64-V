module cpu

pub fn load[T](addr &T) T {
	mut ret := unsafe { T(0) }
	unsafe {
		asm volatile amd64 {
			lock xadd addr, ret
			; +m (*addr) as addr
			  +r (ret)
			; ; memory
		}
	}
	return ret
}

pub fn store[T](mut addr T, value T) {
	unsafe {
		asm volatile amd64 {
			lock xchg addr, value
			; +m (*addr) as addr
			  +r (value)
			; ; memory
		}
	}
}

pub fn cas[T](mut addr T, _exp T, upd T) bool {
	mut ret := false
	mut exp := _exp
	unsafe {
		asm volatile amd64 {
			lock cmpxchg addr, upd
			; +a (exp)
			  +m (*addr) as addr
			  =@ccz (ret)
			; r (upd)
			; memory
		}
	}
	return ret
}
