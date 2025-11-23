module sync

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub struct Queue[T] {
mut:
	buf  &T
	mask u64
	head u64
	tail u64
}

pub fn Queue.new[T](size u64) Queue[T] {
	return Queue[T]{
		buf:  unsafe { &T(C.malloc(size * sizeof(T))) }
		mask: size - 1
		head: 0
		tail: 0
	}
}

pub fn (mut self Queue[T]) push(val T) bool {
	if voidptr(self.buf) == 0 {
		return false
	}

	head := cpu.load(&self.head)
	next := (head + 1) & self.mask
	if next == cpu.load(&self.tail) {
		return false
	}

	unsafe {
		*(&self.buf[head]) = val
	}
	cpu.store(mut &self.head, next)

	return true
}

pub fn (mut self Queue[T]) pop() ?T {
	if voidptr(self.buf) == 0 {
		return none
	}

	tail := cpu.load(&self.tail)
	if tail == cpu.load(&self.head) {
		return none
	}

	val := unsafe { self.buf[tail] }
	cpu.store(mut &self.tail, (tail + 1) & self.mask)

	return val
}
