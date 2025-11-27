module core

import log
import regs

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
		4 { u32(512) }
		1 { u32(8) }
		else { u32(64) }
	}

	mut ep0_ctx := EndpointContext.from(in_ctx_virt, 1, self.ctx_size)
	ep0_ctx.set_ep_type(4)
	ep0_ctx.set_max_packet_size(mps)
	ep0_ctx.set_max_burst_size(0)
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

pub fn (mut self Xhci) get_device_descriptor(slot_id u8) ? {
	desc_virt, desc_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(desc_virt, 1) }

	setup := SetupPacket{
		request_type: 0x80
		request:      req_get_descriptor
		value:        (u16(desc_device) << 8) | 0
		index:        0
		length:       18
	}

	self.usb_control_transfer(
		slot_id:     slot_id
		setup:       setup
		buffer_phys: u64(desc_phys)
	)?

	desc := &DeviceDescriptor(desc_virt)
	log.info(c'Vendor: %04x, Product: %04x', desc.id_vendor, desc.id_product)
	log.info(c'USB Class: %d', desc.device_class)

	if desc.device_class == 0 {
		log.info(c'Class defined in Interface Descriptors')
	} else if desc.device_class == 9 {
		log.info(c'HUB Device')
	} else {
		log.info(c'Unknown Class: %d', desc.device_class)
	}
}

pub fn (mut self Xhci) activate_device(slot_id u8) ? {
	log.debug(c'Setting up endpoints for slot %d...', slot_id)

	header_virt, header_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(header_virt, 1) }

	setup_header := SetupPacket{
		request_type: 0x80
		request:      req_get_descriptor
		value:        (u16(desc_configuration) << 8) | 0
		index:        0
		length:       9
	}

	self.usb_control_transfer(
		slot_id:     slot_id
		setup:       setup_header
		buffer_phys: u64(header_phys)
	)?

	header := &ConfigurationDescriptor(header_virt)
	total_len := header.total_length
	config_val := header.configuration_value

	pages_needed := (u64(total_len) + 4095) / 4096
	config_virt, config_phys := kernel_page_table.alloc_dma(pages_needed)
	defer { kernel_page_table.dealloc_dma(config_virt, pages_needed) }

	setup_full := SetupPacket{
		request_type: 0x80
		request:      req_get_descriptor
		value:        (u16(desc_configuration) << 8) | 0
		index:        0
		length:       total_len
	}

	self.usb_control_transfer(
		slot_id:     slot_id
		setup:       setup_full
		buffer_phys: u64(config_phys)
	)?

	self.configure_endpoints(slot_id, &u8(config_virt), total_len)?
	self.set_configuration(slot_id, config_val)?
	log.success(c'Slot %d configured successfully', slot_id)
}

fn (mut self Xhci) configure_endpoints(slot_id u8, config_virt &u8, len u16) ? {
	in_ctx_virt, in_ctx_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(in_ctx_virt, 1) }

	mut ctrl_ctx := InputControlContext.from(in_ctx_virt)
	ctrl_ctx.add_flags = 1

	mut max_dci := u32(0)
	mut offset := u16(0)

	for offset < len {
		desc_len := unsafe { config_virt[offset] }
		desc_type := unsafe { config_virt[offset + 1] }

		if offset + u16(desc_len) > len {
			break
		}

		if desc_type == desc_endpoint {
			ep_desc := &EndpointDescriptor(config_virt + offset)
			dci := self.setup_one_endpoint(slot_id, in_ctx_virt, ep_desc) or { 0 }
			max_dci = if dci > max_dci { dci } else { max_dci }
		}

		offset += u16(desc_len)
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

fn (mut self Xhci) setup_one_endpoint(slot_id u8, ctx_base u64, desc &EndpointDescriptor) ?u32 {
	addr := desc.endpoint_address
	ep_num := addr & 0x0F
	is_in := (addr & 0x80) != 0

	dci := if is_in { ep_num * 2 + 1 } else { ep_num * 2 }

	if dci < 2 || dci > 31 {
		return none
	}

	mut ring := TransferRing.new()
	self.slots[slot_id].rings[dci] = ring

	attr := desc.attributes & 0x3
	ep_type := if is_in { attr + 4 } else { attr }

	mut ep_ctx := EndpointContext.from(ctx_base, dci, self.ctx_size)
	ep_ctx.set_ep_type(ep_type)
	ep_ctx.set_interval(u32(desc.interval))
	ep_ctx.set_max_burst_size(0)
	ep_ctx.set_error_count(3)
	ep_ctx.set_dequeue_ptr(ring.phys_addr | 1)

	mps := u32(desc.max_packet_size) & 0x7ff
	ep_ctx.set_max_packet_size(mps)

	avg_len := if attr == 3 { u32(1024) } else { u32(3072) }
	ep_ctx.set_average_trb_len(avg_len)

	mut ctrl_ctx := InputControlContext.from(ctx_base)
	ctrl_ctx.add_flags |= (1 << dci)

	return dci
}

pub fn (mut self Xhci) set_configuration(slot_id u8, config_val u8) ? {
	setup := SetupPacket{
		request_type: 0x00
		request:      req_set_configuration
		value:        u16(config_val)
		index:        0
		length:       0
	}

	self.usb_control_transfer(
		slot_id:     slot_id
		setup:       setup
		buffer_phys: 0
	) or {
		log.error(c'Failed to send set configuration request')
		return none
	}
}

@[params]
pub struct ControlTransfer {
pub:
	slot_id     u8
	setup       SetupPacket
	buffer_phys u64
}

fn (mut self Xhci) usb_control_transfer(args ControlTransfer) ? {
	is_dir_in := (args.setup.request_type & 0x80) != 0

	setup, slot_id := args.setup, args.slot_id
	setup_ptr := unsafe { &u32(&args.setup) }
	param_low := unsafe { setup_ptr[0] }
	param_high := unsafe { setup_ptr[1] }

	trt := match true {
		setup.length == 0 { u32(0) }
		is_dir_in { 3 }
		else { 2 }
	}

	mut slot := &self.slots[slot_id]
	setup_trb := Trb.new_setup_stage(param_low, param_high, trt)
	slot.rings[1].enqueue(setup_trb)

	if setup.length > 0 {
		data_trb := Trb.new_data_stage(args.buffer_phys, setup.length, is_dir_in)
		slot.rings[1].enqueue(data_trb)
	}

	status_dir_in := setup.length == 0 || !is_dir_in
	status_trb := Trb.new_status_stage(status_dir_in)
	slot.rings[1].enqueue(status_trb)

	self.doorbell.ring(slot_id, 1)

	evt := self.wait_event(trb_transfer_event, slot_id) or {
		log.error(c'Control transfer timeout (slot %d)', slot_id)
		return none
	}

	code := evt.completion_code()
	if code != 1 && code != 13 {
		log.error(c'Control transfer failed. Code: %d', code)
		return none
	}
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
			self.slots[slot_id].rings[i] = TransferRing{}
		}
	}

	log.debug(c'Slot %d cleanup complete', slot_id)
}
