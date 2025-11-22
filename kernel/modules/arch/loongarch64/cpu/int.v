module cpu

pub fn hcf() {
	asm volatile loongarch64 {
		idle 0
	}
}
