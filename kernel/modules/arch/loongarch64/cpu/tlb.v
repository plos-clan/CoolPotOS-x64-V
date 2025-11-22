module cpu

pub fn invlpg(addr u64) {
	unsafe {
		asm volatile loongarch64 {
			invtlb 0x06, r0, addr
			; ; r (addr)
		}
	}
}
