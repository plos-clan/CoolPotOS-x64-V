module core

import log
import regs

pub fn (mut self Xhci) setup_command_ring() {
	self.cmd_ring = CommandRing.new()
	self.op.set_crcr(self.cmd_ring.phys_addr | 1)
}

pub fn (mut self Xhci) setup_dcbaa(max_slots u8) {
	dcbaa_virt, dcbaa_phys := kernel_page_table.alloc_dma(1)
	self.dcbaa_virt = &u64(dcbaa_virt)

	sp_count := self.cap.max_scratchpad_bufs()
	if sp_count > 0 {
		self.setup_scratchpads(sp_count)
	}

	self.op.set_dcbaap(dcbaa_phys)
	log.debug(c'DCBAA setup at: %#lx', dcbaa_virt)
}

fn (mut self Xhci) setup_scratchpads(count u32) {
	sp_arr_virt, sp_arr_phys := kernel_page_table.alloc_dma(1)
	sp_arr_ptr := &u64(sp_arr_virt)

	unsafe {
		for i in 0 .. count {
			_, buf_phys := kernel_page_table.alloc_dma(1)
			sp_arr_ptr[i] = buf_phys
		}
		self.dcbaa_virt[0] = sp_arr_phys
	}
}

pub fn (mut self Xhci) setup_interrupter() {
	erst_virt, erst_phys := kernel_page_table.alloc_dma(1)

	rt_off := self.cap.rts_off()
	rt_base := self.cap.base_addr + usize(rt_off)

	ir := regs.Interrupter.new(rt_base, 0)
	self.event_ring = EventRing.new(ir.erdp_addr())

	mut entry := &ErstEntry(erst_virt)
	entry.base_addr = u64(self.event_ring.phys_addr)
	entry.size = self.event_ring.capacity

	ir.set_erstsz(1)
	ir.set_erdp(self.event_ring.phys_addr)
	ir.set_erstba(erst_phys)
	ir.enable()

	log.debug(c'Event ring segment table: %#lx', erst_virt)
}
