module cpu

pub fn invlpg(addr u64) {
	asm volatile amd64 {
		invlpg [addr]
		; ; r (addr)
		; memory
	}
}
