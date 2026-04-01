module ctx

@[packed]
pub struct SwitchFrame {
pub mut:
	r15 u64
	r14 u64
	r13 u64
	r12 u64
	rbp u64
	rbx u64
	rip u64
}

@[_naked]
pub fn switch_to(old_sp &u64, new_sp u64) {
	asm volatile amd64 {
		push rbx
		push rbp
		push r12
		push r13
		push r14
		push r15
		mov [rdi], rsp
		mov rsp, rsi
		pop r15
		pop r14
		pop r13
		pop r12
		pop rbp
		pop rbx
		ret
	}
}

@[_naked]
fn context_stub() {
	asm volatile amd64 {
		mov rdi, r13
		call r12
		call r14
		hlt
	}
}

pub fn init_stack(stack_top u64, entry voidptr, ctx voidptr, exit_fn fn ()) u64 {
	mut sp := (stack_top & ~u64(0xf))
	sp -= sizeof(SwitchFrame)

	mut frame := unsafe { &SwitchFrame(sp) }
	frame.rip = u64(&context_stub)
	frame.r12 = u64(entry)
	frame.r13 = u64(ctx)
	frame.r14 = u64(exit_fn)

	return sp
}
