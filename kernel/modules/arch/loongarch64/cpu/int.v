module cpu

pub fn hcf() {
	asm volatile loongarch64 {
		idle 0
	}
}

pub fn spin_hint() {
	asm volatile amd64 {
		dbar 0
	}
}
