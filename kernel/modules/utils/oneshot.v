module utils

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub struct Oneshot[T] {
mut:
	state u32
	value T
}

pub fn Oneshot.new[T]() Oneshot[T] {
	return Oneshot[T]{}
}

pub fn (mut self Oneshot[T]) send(val T) {
	self.value = val
	cpu.store(mut &self.state, u32(1))
}

pub fn (mut self Oneshot[T]) recv() T {
	for !cpu.cas(mut &self.state, u32(1), u32(0)) {
		cpu.hcf()
	}
	return self.value
}

pub fn (mut self Oneshot[T]) reset() {
	cpu.store(mut &self.state, u32(0))
}
