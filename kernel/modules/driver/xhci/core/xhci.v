module core

import regs

pub struct Xhci {
pub mut:
	cap regs.Capability
	op  regs.Operational

	dcbaa_virt    &u64 = unsafe { nil }
	cmd_ring_virt &u64 = unsafe { nil }
}

pub fn Xhci.new(base_addr usize) Xhci {
	cap := regs.Capability.new(base_addr)

	op_base := usize(base_addr) + cap.length()
	op := regs.Operational.new(op_base)

	return Xhci{
		cap: cap
		op:  op
	}
}
