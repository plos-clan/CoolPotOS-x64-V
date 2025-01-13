module sync

import arch.cpu

pub struct Queue[T] {
mut:
	buf  &T
	mask u64
	head u64
	tail u64
	size u64
}

pub fn Queue.new[T](size u64) Queue[T] {
	return Queue[T]{
		buf:  unsafe { &T(C.malloc(int(size * sizeof(T)))) }
		mask: size - 1
		head: 0
		tail: 0
		size: size
	}
}

pub fn (mut self Queue[T]) push(val T) bool {
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
	tail := cpu.load(&self.tail)

	if tail == cpu.load(&self.head) {
		return none
	}

	val := unsafe { self.buf[tail] }

	cpu.store(mut &self.tail, (tail + 1) & self.mask)
	return val
}
