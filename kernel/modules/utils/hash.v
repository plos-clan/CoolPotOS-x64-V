module utils

import log

enum SlotState as u8 {
	empty    = 0
	occupied = 1
	deleted  = 2
}

pub struct Entry[K, V] {
pub mut:
	key K
	val V
mut:
	state SlotState
}

pub struct HashMap[K, V] {
pub mut:
	len u64
mut:
	entries &Entry[K, V] = unsafe { nil }
	cap     u64
	dead    u64
}

@[inline]
fn hash_key(key u64, mask u64) u64 {
	mut x := key
	x ^= x >> 33
	x *= 0xff51afd7ed558ccd
	x ^= x >> 33
	x *= 0xc4ceb9fe1a85ec53
	x ^= x >> 33
	return x & mask
}

pub fn (self &HashMap[K, V]) get(key K) ?&V {
	idx := self.probe_index(key)?
	return unsafe { &self.entries[idx].val }
}

pub fn (mut self HashMap[K, V]) set(key K, val V) {
	mut entry, _ := self.probe_slot(key)
	entry.val = val
}

pub fn (mut self HashMap[K, V]) ensure(key K, default_val V) &V {
	mut entry, exists := self.probe_slot(key)
	if !exists {
		entry.val = default_val
	}
	return &entry.val
}

pub fn (mut self HashMap[K, V]) delete(key K) {
	if idx := self.probe_index(key) {
		unsafe {
			self.entries[idx].state = .deleted
		}
		self.len--
		self.dead++
	}
}

pub fn (mut self HashMap[K, V]) free() {
	if self.cap > 0 {
		C.free(self.entries)
		self.entries = unsafe { nil }
		self.len = 0
		self.cap = 0
		self.dead = 0
	}
}

pub struct HashMapIterator[K, V] {
	data &HashMap[K, V]
mut:
	index u64
}

pub fn (self &HashMap[K, V]) iter() HashMapIterator[K, V] {
	return HashMapIterator[K, V]{
		data: unsafe { self }
	}
}

pub fn (mut self HashMapIterator[K, V]) next() ?&Entry[K, V] {
	for self.index < self.data.cap {
		entry := unsafe { &self.data.entries[self.index] }
		self.index++
		if entry.state == .occupied {
			return entry
		}
	}
	return none
}

fn (mut self HashMap[K, V]) expand() {
	old_cap := self.cap
	new_cap := if old_cap == 0 { u64(8) } else { old_cap << 1 }

	new_ptr := C.calloc(new_cap, sizeof(Entry[K, V]))
	new_entries := unsafe { &Entry[K, V](new_ptr) }

	if new_entries == unsafe { nil } {
		log.panic(c'HashMap: out of memory')
	}

	mask := new_cap - 1
	for i in 0 .. old_cap {
		unsafe {
			old_entry := &self.entries[i]
			if old_entry.state != .occupied {
				continue
			}

			mut idx := hash_key(u64(old_entry.key), mask)
			for new_entries[idx].state != .empty {
				idx = (idx + 1) & mask
			}
			new_entries[idx] = *old_entry
		}
	}

	if old_cap > 0 {
		C.free(self.entries)
	}

	self.entries = new_entries
	self.cap = new_cap
	self.dead = 0
}

fn (self &HashMap[K, V]) probe_index(key K) ?u64 {
	if self.len == 0 {
		return none
	}
	mask := self.cap - 1
	mut idx := hash_key(u64(key), mask)

	for {
		entry := unsafe { &self.entries[idx] }
		if entry.state == .empty {
			return none
		}
		if entry.state == .occupied && entry.key == key {
			return idx
		}
		idx = (idx + 1) & mask
	}
	return none
}

fn (mut self HashMap[K, V]) probe_slot(key K) (&Entry[K, V], bool) {
	if self.cap == 0 || (self.len + self.dead) * 4 >= self.cap * 3 {
		self.expand()
	}

	mask := self.cap - 1
	mut idx := hash_key(u64(key), mask)
	mut recycle_idx := i64(-1)

	for {
		mut entry := unsafe { &self.entries[idx] }

		if entry.state == .occupied && entry.key == key {
			return entry, true
		}

		if entry.state == .empty {
			if recycle_idx != -1 {
				idx = u64(recycle_idx)
				entry = unsafe { &self.entries[idx] }
				self.dead--
			}

			entry.key = key
			entry.state = .occupied
			self.len++
			return entry, false
		}

		if entry.state == .deleted && recycle_idx == -1 {
			recycle_idx = idx
		}

		idx = (idx + 1) & mask
	}

	log.panic(c'HashMap: probe slot failed')
}
