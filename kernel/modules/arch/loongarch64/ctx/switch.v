module ctx

@[packed]
pub struct SwitchFrame {
pub mut:
	ra  u64
	fp  u64
	s0  u64
	s1  u64
	s2  u64
	s3  u64
	s4  u64
	s5  u64
	s6  u64
	s7  u64
	s8  u64
	pad u64
}

@[_naked]
pub fn switch_to(old_sp &u64, new_sp u64) {
	asm volatile loongarch64 {
		addi.d r3, r3, '-96'
		st.d r1, r3, 0
		st.d r22, r3, 8
		st.d r23, r3, 16
		st.d r24, r3, 24
		st.d r25, r3, 32
		st.d r26, r3, 40
		st.d r27, r3, 48
		st.d r28, r3, 56
		st.d r29, r3, 64
		st.d r30, r3, 72
		st.d r31, r3, 80
		st.d r3, r4, 0
		addi.d r3, r5, 0
		ld.d r1, r3, 0
		ld.d r22, r3, 8
		ld.d r23, r3, 16
		ld.d r24, r3, 24
		ld.d r25, r3, 32
		ld.d r26, r3, 40
		ld.d r27, r3, 48
		ld.d r28, r3, 56
		ld.d r29, r3, 64
		ld.d r30, r3, 72
		ld.d r31, r3, 80
		addi.d r3, r3, 96
		jirl r0, r1, 0
	}
}

@[_naked]
fn context_stub() {
	asm volatile loongarch64 {
		addi.d r4, r24, 0
		jirl r1, r23, 0
		jirl r1, r25, 0
		idle 0
	}
}

pub fn init_stack(stack_top u64, entry voidptr, ctx voidptr, exit_fn fn ()) u64 {
	mut sp := (stack_top & ~u64(0xf))
	sp -= sizeof(SwitchFrame)

	mut frame := unsafe { &SwitchFrame(sp) }
	frame.ra = u64(&context_stub)
	frame.s0 = u64(entry)
	frame.s1 = u64(ctx)
	frame.s2 = u64(exit_fn)

	return sp
}
