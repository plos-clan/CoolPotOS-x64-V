module cpu

pub fn read_pgdh() u64 {
	mut val := u64(0)
	unsafe {
		asm volatile loongarch64 {
			csrrd val, 0x1a
			; =r (val)
		}
	}
	return val
}

pub fn write_eentry(val u64) {
	unsafe {
		asm volatile loongarch64 {
			csrwr val, 0xc
			; ; r (val)
		}
	}
}
