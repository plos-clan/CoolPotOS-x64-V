module async

pub struct Future[T] {
pub mut:
	is_ready bool
	value    T
	waker    ?Waker
}

pub fn Future.new[T]() Future[T] {
	return Future[T]{}
}

pub fn (mut self Future[T]) await() T {
	for !self.is_ready {
		self.waker = executor.current
		executor.park()
	}
	return self.value
}

pub fn (mut self Future[T]) reset() {
	self.is_ready = false
	self.waker = none
}

pub fn (mut self Future[T]) resolve(val T) {
	self.value = val
	self.is_ready = true
	mut w := self.waker or { return }
	w.wake()
	self.waker = none
}
