module utils

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}

pub struct Queue[T] {
mut:
	buf  &T
	mask usize
	head usize
	tail usize
}

pub fn Queue.new[T](size usize) Queue[T] {
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

pub fn (mut self Queue[T]) peek_chunk() (&T, usize) {
	if voidptr(self.buf) == 0 {
		return unsafe { nil }, 0
	}

	head := cpu.load(&self.head)
	tail := cpu.load(&self.tail)

	if head == tail {
		return unsafe { nil }, 0
	}

	len := if head > tail {
		head - tail
	} else {
		(self.mask + 1) - tail
	}

	return unsafe { &self.buf[tail] }, len
}

pub fn (mut self Queue[T]) consume(count usize) {
	tail := cpu.load(&self.tail)
	cpu.store(mut &self.tail, (tail + count) & self.mask)
}

pub fn (mut self Queue[T]) push_many(vals &T, count usize) usize {
	if voidptr(self.buf) == 0 || count == 0 {
		return 0
	}

	head := cpu.load(&self.head)
	tail := cpu.load(&self.tail)
	avail := self.mask - ((head - tail) & self.mask)

	mut to_push := count
	if to_push > avail {
		to_push = avail
	}

	if to_push == 0 {
		return 0
	}

	right_space := self.mask + 1 - head
	if to_push <= right_space {
		push_bytes := to_push * sizeof(T)
		C.memcpy(unsafe { &self.buf[head] }, vals, push_bytes)
	} else {
		right_bytes := right_space * sizeof(T)
		wrap_count := to_push - right_space
		wrap_bytes := wrap_count * sizeof(T)
		C.memcpy(unsafe { &self.buf[head] }, vals, right_bytes)
		C.memcpy(self.buf, vals + right_space, wrap_bytes)
	}

	cpu.store(mut &self.head, (head + to_push) & self.mask)
	return to_push
}
