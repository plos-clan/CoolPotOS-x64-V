module utils

import log

pub struct Vec[T] {
mut:
	data &T = unsafe { nil }
	len  u64
	cap  u64
}

pub fn (self &Vec[T]) get(index u64) &T {
	if index >= self.len {
		log.panic(c'Vec out of bounds')
	}
	unsafe {
		return &self.data[index]
	}
}

pub fn (self &Vec[T]) first() ?&T {
	if self.len == 0 {
		return none
	}
	unsafe {
		return &self.data[0]
	}
}

pub fn (self &Vec[T]) last() ?&T {
	if self.len == 0 {
		return none
	}
	unsafe {
		return &self.data[self.len - 1]
	}
}

pub fn (mut self Vec[T]) set(index u64, val T) {
	if index >= self.len {
		log.panic(c'Vec out of bounds')
	}
	unsafe {
		self.data[index] = val
	}
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
	unsafe {
		return self.data[self.len]
	}
}

pub fn (mut self Vec[T]) free() {
	if self.cap > 0 {
		C.free(self.data)
		self.data = unsafe { nil }
		self.len = 0
		self.cap = 0
	}
}

fn (mut self Vec[T]) grow() {
	new_cap := if self.cap == 0 {
		u64(8)
	} else {
		self.cap * 2
	}

	new_size := usize(new_cap * sizeof(T))
	new_ptr := C.realloc(self.data, new_size)

	if new_ptr == unsafe { nil } {
		log.panic(c'Vec: out of memory')
	}

	self.cap = new_cap
	self.data = new_ptr
}

pub struct VecIterator[T] {
	vec &Vec[T]
mut:
	index u64
}

pub fn (self &Vec[T]) iter() VecIterator[T] {
	return VecIterator[T]{
		vec: unsafe { self }
	}
}

pub fn (mut self VecIterator[T]) next() ?&T {
	if self.index >= self.vec.len {
		return none
	}
	defer { self.index++ }

	unsafe {
		return &self.vec.data[self.index]
	}
}
