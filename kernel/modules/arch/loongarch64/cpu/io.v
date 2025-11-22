module cpu

pub fn mmio_in[T](addr &T) T {
	mut ret := T(0)
	unsafe {
		$if sizeof(T) == 1 {
			asm volatile loongarch64 {
				ld.bu ret, addr, 0
				; =r (ret)
				; r (addr)
				; memory
			}
		} $else $if sizeof(T) == 2 {
			asm volatile loongarch64 {
				ld.hu ret, addr, 0
				; =r (ret)
				; r (addr)
				; memory
			}
		} $else $if sizeof(T) == 4 {
			asm volatile loongarch64 {
				ld.wu ret, addr, 0
				; =r (ret)
				; r (addr)
				; memory
			}
		} $else $if sizeof(T) == 8 {
			asm volatile loongarch64 {
				ld.d ret, addr, 0
				; =r (ret)
				; r (addr)
				; memory
			}
		}
	}
	return ret
}

pub fn mmio_out[T](addr &T, value T) {
	unsafe {
		$if sizeof(T) == 1 {
			asm volatile loongarch64 {
				st.b value, addr, 0
				dbar 0
				; ; r (value)
				  r (addr)
				; memory
			}
		} $else $if sizeof(T) == 2 {
			asm volatile loongarch64 {
				st.h value, addr, 0
				dbar 0
				; ; r (value)
				  r (addr)
				; memory
			}
		} $else $if sizeof(T) == 4 {
			asm volatile loongarch64 {
				st.w value, addr, 0
				dbar 0
				; ; r (value)
				  r (addr)
				; memory
			}
		} $else $if sizeof(T) == 8 {
			asm volatile loongarch64 {
				st.d value, addr, 0
				dbar 0
				; ; r (value)
				  r (addr)
				; memory
			}
		}
	}
}
