module cpu

pub fn load[T](addr &T) T {
	mut ret := unsafe { T(0) }
	mut zero := unsafe { T(0) }
	unsafe {
		$if sizeof(T) == 8 {
			asm volatile loongarch64 {
				amadd_db.d ret, zero, addr
				; =&r (ret)
				; r (zero)
				  r (addr)
				; memory
			}
		} $else {
			asm volatile loongarch64 {
				amadd_db.w ret, zero, addr
				; =&r (ret)
				; r (zero)
				  r (addr)
				; memory
			}
		}
	}
	return ret
}

pub fn store[T](mut addr T, value T) {
	mut tmp := unsafe { T(0) }
	unsafe {
		$if sizeof(T) == 8 {
			asm volatile loongarch64 {
				amswap_db.d tmp, value, addr
				; =&r (tmp)
				; r (value)
				  r (addr)
				; memory
			}
		} $else {
			asm volatile loongarch64 {
				amswap_db.w tmp, value, addr
				; =&r (tmp)
				; r (value)
				  r (addr)
				; memory
			}
		}
	}
}

pub fn cas[T](mut addr T, _exp T, upd T) bool {
	mut prev := _exp
	unsafe {
		$if sizeof(T) == 8 {
			asm volatile loongarch64 {
				amcas_db.d prev, upd, addr
				; +r (prev)
				; r (upd)
				  r (addr)
				; memory
			}
		} $else {
			asm volatile loongarch64 {
				amcas_db.w prev, upd, addr
				; +r (prev)
				; r (upd)
				  r (addr)
				; memory
			}
		}
	}
	return prev == _exp
}
