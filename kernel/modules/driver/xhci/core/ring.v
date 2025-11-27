module core

$if amd64 {
	import arch.amd64.cpu
} $else {
	import arch.loongarch64.cpu
}
import mem

pub struct CommandRing {
pub mut:
	base        &Trb = unsafe { nil }
	phys_addr   u64
	capacity    u32
	enqueue_idx u32
	cycle_state bool
}

pub fn CommandRing.new() CommandRing {
	ring_virt, ring_phys := kernel_page_table.alloc_dma(1)
	trb_count := u32(0x1000 / sizeof(Trb))

	return CommandRing{
		base:        unsafe { &Trb(ring_virt) }
		phys_addr:   ring_phys
		capacity:    trb_count
		enqueue_idx: 0
		cycle_state: true
	}
}

pub fn (mut self CommandRing) enqueue(trb Trb) {
	if self.enqueue_idx == self.capacity - 1 {
		self.link_to_start()
	}

	target_idx := self.enqueue_idx

	mut write_trb := trb
	if self.cycle_state {
		write_trb.control |= 1
	} else {
		write_trb.control &= ~u32(1)
	}

	unsafe {
		self.base[target_idx] = write_trb
	}
	self.enqueue_idx++
}

fn (mut self CommandRing) link_to_start() {
	link_idx := self.enqueue_idx

	mut link_trb := Trb{
		param_low:  u32(self.phys_addr & 0xFFFFFFFF)
		param_high: u32(self.phys_addr >> 32)
		status:     0
		control:    6 << 10
	}

	link_trb.control |= (1 << 1)

	if self.cycle_state {
		link_trb.control |= 1
	} else {
		link_trb.control &= ~u32(1)
	}

	unsafe {
		self.base[link_idx] = link_trb
	}
	self.enqueue_idx = 0
	self.cycle_state = !self.cycle_state
}

pub struct EventRing {
pub mut:
	base        &Trb = unsafe { nil }
	phys_addr   u64
	capacity    u32
	dequeue_idx u32
	cycle_state bool
	erdp_reg    &u32 = unsafe { nil }
}

pub fn EventRing.new(erdp_reg &u32) EventRing {
	ring_virt, ring_phys := kernel_page_table.alloc_dma(1)
	trb_count := u32(0x1000 / sizeof(Trb))

	return EventRing{
		base:        unsafe { &Trb(ring_virt) }
		phys_addr:   ring_phys
		capacity:    trb_count
		dequeue_idx: 0
		cycle_state: true
		erdp_reg:    unsafe { erdp_reg }
	}
}

pub fn (self EventRing) has_event() bool {
	unsafe {
		trb := self.base[self.dequeue_idx]
		expected := if self.cycle_state { 1 } else { 0 }
		return (trb.control & 1) == expected
	}
}

pub fn (mut self EventRing) pop() ?Trb {
	if !self.has_event() {
		return none
	}

	unsafe {
		trb := self.base[self.dequeue_idx]
		self.dequeue_idx++

		if self.dequeue_idx == self.capacity {
			self.dequeue_idx = 0
			self.cycle_state = !self.cycle_state
		}

		return trb
	}
}

pub fn (self EventRing) update_erdp() {
	current_phys := self.phys_addr + u64(self.dequeue_idx * 16)
	val_to_write := current_phys | (1 << 3)

	low := u32(val_to_write & 0xFFFFFFFF)
	high := u32(val_to_write >> 32)

	cpu.mmio_out[u32](self.erdp_reg, low)
	cpu.mmio_out[u32](self.erdp_reg + 1, high)
}

pub struct TransferRing {
pub mut:
	base        &Trb = unsafe { nil }
	phys_addr   u64
	capacity    u32
	enqueue_idx u32
	cycle_state bool
}

pub fn TransferRing.new() TransferRing {
	ring_virt, ring_phys := kernel_page_table.alloc_dma(1)
	trb_count := u32(0x1000 / sizeof(Trb))

	return TransferRing{
		base:        unsafe { &Trb(ring_virt) }
		phys_addr:   ring_phys
		capacity:    trb_count
		enqueue_idx: 0
		cycle_state: true
	}
}

pub fn (mut self TransferRing) enqueue(trb Trb) {
	if self.enqueue_idx == self.capacity - 1 {
		self.link_to_start()
	}

	target_idx := self.enqueue_idx
	mut write_trb := trb

	if self.cycle_state {
		write_trb.control |= 1
	} else {
		write_trb.control &= ~u32(1)
	}

	unsafe {
		self.base[target_idx] = write_trb
	}
	self.enqueue_idx++
}

fn (mut self TransferRing) link_to_start() {
	link_idx := self.enqueue_idx
	mut link_trb := Trb{
		param_low:  u32(self.phys_addr & 0xFFFFFFFF)
		param_high: u32(self.phys_addr >> 32)
		control:    (u32(trb_link) << 10) | (1 << 1)
	}

	if self.cycle_state {
		link_trb.control |= 1
	} else {
		link_trb.control &= ~u32(1)
	}

	unsafe {
		self.base[link_idx] = link_trb
	}
	self.enqueue_idx = 0
	self.cycle_state = !self.cycle_state
}

pub fn (mut self TransferRing) free() {
	if self.phys_addr != 0 {
		virt_addr := mem.phys_to_virt(self.phys_addr)
		kernel_page_table.dealloc_dma(virt_addr, 1)
	}
}
