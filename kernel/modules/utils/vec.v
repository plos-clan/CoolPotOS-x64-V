module utils

import log

pub struct Vec[T] {
pub mut:
	data &T
	len  u64
	cap  u64
}

pub fn (mut self Vec[T]) push(val T) {
	if self.len >= self.cap {
		self.grow()
	}
	unsafe {
		self.data[self.len] = val
	}
	self.len++
}

pub fn (mut self Vec[T]) pop() ?T {
	if self.len == 0 {
		return none
	}
	self.len--
	return unsafe { self.data[self.len] }
}

pub fn (self &Vec[T]) get(index u64) ?&T {
	if index >= self.len {
		return none
	}
	return unsafe { &self.data[index] }
}

pub fn (mut self Vec[T]) set(index u64, val T) {
	if index >= self.len {
		log.panic(c'Vec out of bounds')
	}
	unsafe {
		self.data[index] = val
	}
}

pub fn (mut self Vec[T]) free() {
	if self.cap > 0 && self.data != unsafe { nil } {
		unsafe { C.free(self.data) }
		self.data = unsafe { nil }
		self.len = 0
		self.cap = 0
	}
}

fn (mut self Vec[T]) grow() {
	new_cap := if self.cap == 0 { u64(8) } else { self.cap * 2 }
	new_size := usize(new_cap * sizeof(T))

	unsafe {
		new_ptr := &T(C.malloc(new_size))

		if self.cap > 0 && self.data != 0 {
			C.memcpy(new_ptr, self.data, usize(self.len * sizeof(T)))
			C.free(self.data)
		}

		self.data = new_ptr
		self.cap = new_cap
	}
}
