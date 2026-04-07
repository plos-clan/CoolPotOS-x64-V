module async

import sync { SpinLock }
import utils { Queue }

pub struct Oneshot[T] {
pub mut:
	is_ready bool
	value    ?T
	waker    ?&Routine
}

pub fn Oneshot.new[T]() Oneshot[T] {
	return Oneshot[T]{}
}

pub fn (mut self Oneshot[T]) recv() ?T {
	for !self.is_ready {
		self.waker = executor.current
		executor.park()
	}
	return self.value
}

pub fn (mut self Oneshot[T]) send(val T) {
	self.value = val
	self.is_ready = true
	if mut w := self.waker {
		w.wake()
	}
	self.waker = none
}

pub fn (mut self Oneshot[T]) cancel() {
	self.is_ready = true
	self.value = none
	if mut w := self.waker {
		w.wake()
	}
	self.waker = none
}

pub fn (mut self Oneshot[T]) reset() {
	self.is_ready = false
	self.value = none
	self.waker = none
}

pub struct Channel[T] {
mut:
	queue Queue[T]
	sem   Semaphore
	lock  SpinLock
}

pub fn (mut c Channel[T]) push(val T) {
	c.lock.lock()
	pushed := c.queue.push(val)
	c.lock.unlock()
	if pushed {
		c.sem.release()
	}
}

pub fn (mut c Channel[T]) pop() T {
	c.sem.acquire()
	return c.queue.pop() or { log.panic('Logic error') }
}
