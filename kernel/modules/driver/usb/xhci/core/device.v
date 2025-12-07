module core

import bus { UsbEndpoint }
import defs
import log
import utils { Vec }

pub fn (mut self Xhci) address_device(port_id int, slot_id u8, speed_id u32) ? {
	log.debug(c'Addressing device on slot %d...', slot_id)

	out_ctx_virt, out_ctx_phys := kernel_page_table.alloc_dma(1)
	unsafe {
		self.dcbaa_virt[slot_id] = u64(out_ctx_phys)
	}
	ep0_ring := TransferRing.new()
	self.slots[slot_id] = Slot{
		id:           slot_id
		active:       true
		port_id:      port_id
		speed:        speed_id
		out_ctx_virt: &u64(out_ctx_virt)
		out_ctx_phys: u64(out_ctx_phys)
	}
	self.slots[slot_id].rings[1] = ep0_ring

	in_ctx_virt, in_ctx_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(in_ctx_virt, 1) }

	mut ctrl_ctx := InputControlContext.from(in_ctx_virt)
	ctrl_ctx.add_flags = (1 << 0) | (1 << 1)

	mut slot_ctx := SlotContext.from(in_ctx_virt, self.ctx_size)
	slot_ctx.set_entries(1)
	slot_ctx.set_root_hub_port(u32(port_id))
	slot_ctx.set_route_string(0)
	slot_ctx.set_speed(speed_id)

	mps := match speed_id {
		defs.speed_super { u32(512) }
		defs.speed_low { 8 }
		else { 64 }
	}

	mut ep0_ctx := EndpointContext.from(in_ctx_virt, 1, self.ctx_size)
	ep0_ctx.set_ep_type(defs.ep_type_control + 4)
	ep0_ctx.set_max_packet_size(mps)
	ep0_ctx.set_max_burst(0)
	ep0_ctx.set_error_count(3)
	ep0_ctx.set_average_trb_len(8)
	ep0_ctx.set_dequeue_ptr(ep0_ring.phys_addr | 1)

	cmd := Trb.new_address_device(in_ctx_phys, slot_id)
	code, _ := self.send_command(cmd) or {
		log.error(c'Address Device command timeout')
		return none
	}

	if code != 1 {
		log.error(c'Address Device failed code: %d', code)
		return none
	}
}

pub fn (mut self Xhci) configure_endpoints(slot_id u8, endpoints &Vec[UsbEndpoint]) ? {
	in_ctx_virt, in_ctx_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(in_ctx_virt, 1) }

	mut ctrl_ctx := InputControlContext.from(in_ctx_virt)
	ctrl_ctx.add_flags = 1

	mut max_dci := u32(0)

	for ep in endpoints.iter() {
		dci := self.setup_one_endpoint(slot_id, in_ctx_virt, ep) or { 0 }

		if dci > max_dci {
			max_dci = dci
		}
	}

	mut slot_ctx := SlotContext.from(in_ctx_virt, self.ctx_size)
	slot_ctx.set_entries(max_dci)

	cmd := Trb.new_configure_endpoint(in_ctx_phys, slot_id)
	code, _ := self.send_command(cmd) or {
		log.error(c'Configure endpoint command timeout')
		return none
	}

	if code != 1 {
		log.error(c'Configure endpoint failed: %d', code)
		return none
	}
}

fn (mut self Xhci) setup_one_endpoint(slot_id u8, ctx_base u64, ep &UsbEndpoint) ?u32 {
	addr := ep.desc.endpoint_address
	ep_num := addr & 0x0f
	is_in := (addr & defs.req_dir_in) != 0

	dci := if is_in { ep_num * 2 + 1 } else { ep_num * 2 }
	if dci < 2 || dci > 31 {
		return none
	}

	mut ring := TransferRing.new()
	self.slots[slot_id].rings[dci] = ring

	attr := ep.desc.attributes & 0x3
	ep_type := if is_in { attr + 4 } else { attr }

	raw_mps := u32(ep.desc.max_packet_size)
	mps := raw_mps & 0x7ff
	speed := self.slots[slot_id].speed

	error_count := match attr {
		defs.ep_type_iso { u32(0) }
		else { 3 }
	}

	avg_trb_len := match attr {
		defs.ep_type_control { 8 }
		defs.ep_type_int { 1024 }
		defs.ep_type_iso { mps }
		else { 3072 }
	}

	is_iso_int := attr == defs.ep_type_int || attr == defs.ep_type_iso
	hs_burst := if is_iso_int { (raw_mps >> 11) & 0x03 } else { 0 }
	ss_burst := if ss := ep.ss_desc { u32(ss.max_burst) } else { 0 }

	max_burst := match speed {
		defs.speed_high { hs_burst }
		defs.speed_super { ss_burst }
		else { 0 }
	}

	raw_ival := u32(ep.desc.interval)
	ls_fs_interval := if raw_ival > 0 { utils.ilog2(raw_ival) + 3 } else { 0 }
	hs_ss_interval := if raw_ival > 0 { raw_ival - 1 } else { 0 }

	mut interval := u32(0)
	if is_iso_int {
		interval = match speed {
			defs.speed_low, defs.speed_full { ls_fs_interval }
			else { hs_ss_interval }
		}
	}

	is_ss_iso := speed == defs.speed_super && attr == defs.ep_type_iso
	ss_iso_mult := if ss := ep.ss_desc { u32(ss.attributes & 0x3) } else { 0 }
	mult := if is_ss_iso { ss_iso_mult } else { 0 }

	mut max_esit_payload := u32(0)
	if is_iso_int {
		max_esit_payload = match speed {
			defs.speed_super {
				if ss := ep.ss_desc {
					u32(ss.bytes_per_interval)
				} else {
					mps * (max_burst + 1)
				}
			}
			else {
				mps * (max_burst + 1)
			}
		}
	}

	mut ep_ctx := EndpointContext.from(ctx_base, dci, self.ctx_size)
	ep_ctx.set_ep_type(ep_type)
	ep_ctx.set_interval(interval)
	ep_ctx.set_mult(mult)
	ep_ctx.set_max_burst(max_burst)
	ep_ctx.set_error_count(error_count)
	ep_ctx.set_dequeue_ptr(ring.phys_addr | 1)
	ep_ctx.set_max_packet_size(mps)
	ep_ctx.set_average_trb_len(avg_trb_len)
	ep_ctx.set_max_esit_payload(max_esit_payload)

	mut ctrl_ctx := InputControlContext.from(ctx_base)
	ctrl_ctx.add_flags |= (1 << dci)

	return dci
}

fn (mut self Xhci) cleanup_slot_on_failure(slot_id u8) {
	log.debug(c'Cleaning up resources for slot %d', slot_id)

	if self.slots[slot_id].active {
		self.disable_slot(slot_id)
	}
	self.slots[slot_id].active = false

	if self.slots[slot_id].out_ctx_virt != 0 {
		virt_addr := self.slots[slot_id].out_ctx_virt
		kernel_page_table.dealloc_dma(virt_addr, 1)
		self.slots[slot_id].out_ctx_virt = unsafe { nil }
	}

	if self.dcbaa_virt != unsafe { nil } {
		unsafe {
			self.dcbaa_virt[slot_id] = 0
		}
	}

	for i in 1 .. 32 {
		if self.slots[slot_id].rings[i].phys_addr != 0 {
			self.slots[slot_id].rings[i].free()
		}
	}

	log.debug(c'Slot %d cleanup complete', slot_id)
}
