module sync

$if amd64 {
	import arch.amd64.cpu
} $else $if loongarch64 {
	import arch.loongarch64.cpu
}

struct SpinLock {
mut:
	locked u32
}

pub fn SpinLock.new() SpinLock {
	return SpinLock{
		locked: 0
	}
}

pub fn (mut self SpinLock) lock() {
	for {
		if cpu.cas(mut &self.locked, 0, 1) {
			break
		}
	}
}

pub fn (mut self SpinLock) unlock() {
	cpu.store(mut &self.locked, 0)
}
