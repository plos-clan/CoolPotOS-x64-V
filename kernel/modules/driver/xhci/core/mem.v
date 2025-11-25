module core

import log
import regs

pub fn (mut self Xhci) setup_dcbaa(max_slots u8) {
	dcbaa_virt, dcbaa_phys := kernel_page_table.alloc_dma(1)
	self.dcbaa_virt = &u64(dcbaa_virt)

	sp_count := self.cap.max_scratchpad_bufs()
	if sp_count > 0 {
		sp_arr_virt, sp_arr_phys := kernel_page_table.alloc_dma(1)
		sp_arr_ptr := &u64(sp_arr_virt)

		for i in 0 .. sp_count {
			_, buf_phys := kernel_page_table.alloc_dma(1)
			unsafe {
				sp_arr_ptr[i] = buf_phys
			}
		}

		unsafe {
			self.dcbaa_virt[0] = sp_arr_phys
		}
	}

	self.op.set_dcbaap(dcbaa_phys)
	log.debug(c'DCBAA setup at: %#lx', dcbaa_virt)
}

pub fn (mut self Xhci) setup_command_ring() {
	ring_virt, ring_phys := kernel_page_table.alloc_dma(1)
	self.cmd_ring_virt = &u64(ring_virt)

	self.op.set_crcr(ring_phys)
	log.debug(c'Command ring at: %#lx', ring_virt)
}

pub fn (self Xhci) setup_interrupter() {
	ring_virt, ring_phys := kernel_page_table.alloc_dma(1)
	erst_virt, erst_phys := kernel_page_table.alloc_dma(1)

	trb_count := u32(4096 / 16)
	mut entry := &ErstEntry(erst_virt)
	entry.base_addr = u64(ring_phys)
	entry.size = trb_count

	rt_off := self.cap.rts_off()
	rt_base := self.cap.base_addr + usize(rt_off)

	ir := regs.Interrupter.new(rt_base, 0)
	ir.set_erstsz(1)
	ir.set_erdp(ring_phys)
	ir.set_erstba(erst_phys)
	ir.enable()

	log.debug(c'Event ring: %#lx', ring_virt)
	log.debug(c'Event ring segment table: %#lx', erst_virt)
}
