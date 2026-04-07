module async

import log
import utils { Queue }

pub struct Mutex {
mut:
	locked  bool
	owner   ?&Routine
	waiters Queue[&Routine]
}

pub fn Mutex.new() Mutex {
	return Mutex{
		locked:  false
		owner:   none
		waiters: Queue.new[&Routine](pool_capacity)
	}
}

pub fn (mut self Mutex) lock() {
	for self.locked {
		self.waiters.push(executor.current)
		executor.park()
	}
	self.locked = true
	self.owner = executor.current
}

pub fn (mut self Mutex) unlock() {
	owner := self.owner or {
		log.panic(c'Unlock but not locked')
		return
	}

	if owner != executor.current {
		log.panic(c'Unlock by a non-owner routine')
	}

	self.locked = false
	self.owner = none

	if mut next := self.waiters.pop() {
		next.wake()
	}
}

pub struct Semaphore {
mut:
	count   u32
	waiters Queue[&Routine]
}

pub fn Semaphore.new(permits u32) Semaphore {
	return Semaphore{
		count:   permits
		waiters: Queue.new[&Routine](pool_capacity)
	}
}

pub fn (mut self Semaphore) acquire() {
	for self.count == 0 {
		self.waiters.push(executor.current)
		executor.park()
	}
	self.count--
}

pub fn (mut self Semaphore) release() {
	self.count++
	if mut r := self.waiters.pop() {
		r.wake()
	}
}
