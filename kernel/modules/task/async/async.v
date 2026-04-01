@[has_globals]
module async

import mem
import log
import utils { Queue }

$if amd64 {
	import arch.amd64.cpu
	import arch.amd64.ctx
} $else {
	import arch.loongarch64.cpu
	import arch.loongarch64.ctx
}

pub type RoutineFn = fn (arg voidptr)

const page_size = u64(4096)
const stack_pages = u64(2)
const guard_pages = u64(1)
const pool_capacity = 256
const base_virt_addr = u64(0xffffa00000000000)

__global executor Executor

pub interface Waker {
mut:
	wake()
}

pub struct Routine {
pub mut:
	sp        u64
	stack_top u64
}

pub struct Executor {
pub mut:
	ready_queue Queue[usize]
	free_queue  Queue[usize]
	main_sp     u64
	current     &Routine = unsafe { nil }
	pool        [pool_capacity]Routine
}

pub fn (mut e Executor) run() {
	for {
		addr := e.ready_queue.pop() or {
			cpu.hcf()
			continue
		}
		e.current = unsafe { &Routine(addr) }
		ctx.switch_to(&e.main_sp, e.current.sp)
	}
}

pub fn (mut r Routine) wake() {
	executor.ready_queue.push(usize(r))
}

pub fn (mut e Executor) yield() {
	e.ready_queue.push(usize(e.current))
	e.park()
}

@[inline]
fn (mut e Executor) park() {
	ctx.switch_to(&e.current.sp, e.main_sp)
}

fn (mut e Executor) exit() {
	e.free_queue.push(usize(e.current))
	e.park()
}

pub fn (mut e Executor) init() {
	e.ready_queue = Queue.new[usize](pool_capacity)
	e.free_queue = Queue.new[usize](pool_capacity)

	total_pages := stack_pages * pool_capacity
	phys_base := mem.alloc_frames(total_pages) or {
		log.panic(c'Out of memory for async pool')
		return
	}

	mut vaddr := base_virt_addr
	mut paddr := u64(phys_base)

	flags := mem.MappingType.kernel_data.flags()

	for i in 0 .. pool_capacity {
		vaddr += guard_pages * page_size

		for _ in 0 .. stack_pages {
			kernel_page_table.map_to(vaddr, paddr, flags)
			vaddr += page_size
			paddr += page_size
		}

		e.pool[i] = Routine{
			stack_top: vaddr
		}
		e.free_queue.push(usize(&e.pool[i]))
	}
}

pub fn (mut e Executor) spawn(entry RoutineFn, arg voidptr) {
	addr := e.free_queue.pop() or {
		log.panic(c'Async pool exhausted')
		return
	}

	mut target := unsafe { &Routine(addr) }
	target.sp = ctx.init_stack(target.stack_top, entry, arg, || executor.exit())
	e.ready_queue.push(usize(target))
}
