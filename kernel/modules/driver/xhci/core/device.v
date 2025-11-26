module core

import log

pub fn (mut self Xhci) address_device(port_id int, slot_id u8, speed_id u32) bool {
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

	mut ctx := &InputContext(in_ctx_virt)
	ctx.control.add_flags = (1 << 0) | (1 << 1)
	ctx.slot.set_entries(1)
	ctx.slot.set_root_hub_port(u32(port_id))
	ctx.slot.set_route_string(0)
	ctx.slot.set_speed(speed_id)

	mps := match speed_id {
		4 { u32(512) }
		1 { u32(8) }
		else { u32(64) }
	}

	ctx.ep0.set_ep_type(4)
	ctx.ep0.set_max_packet_size(mps)
	ctx.ep0.set_max_burst_size(0)
	ctx.ep0.set_error_count(3)
	ctx.ep0.set_average_trb_len(8)
	ctx.ep0.set_dequeue_ptr(ep0_ring.phys_addr | 1)

	cmd := Trb{
		param_low:  u32(in_ctx_phys & 0xFFFFFFFF)
		param_high: u32(in_ctx_phys >> 32)
		control:    (u32(trb_address_device) << 10) | (u32(slot_id) << 24)
	}

	code, _ := self.send_command(cmd) or {
		log.error(c'Address Device command timeout')
		self.cleanup_slot_on_failure(slot_id)
		return false
	}

	if code != 1 {
		log.error(c'Address Device failed code: %d', code)
		self.cleanup_slot_on_failure(slot_id)
		return false
	}

	return true
}

fn (mut self Xhci) cleanup_slot_on_failure(slot_id u8) {
	self.slots[slot_id].active = false

	if self.slots[slot_id].out_ctx_virt != 0 {
		virt_addr := self.slots[slot_id].out_ctx_virt
		kernel_page_table.dealloc_dma(virt_addr, 1)
		self.slots[slot_id].out_ctx_virt = unsafe { nil }
	}

	unsafe {
		self.dcbaa_virt[slot_id] = 0
	}
	self.slots[slot_id].rings[1].free()
}

pub fn (mut self Xhci) set_configuration(slot_id u8, config_val u8) ? {
	log.debug(c'Sending set configuration %d...', config_val)

	setup := SetupPacket{
		request_type: 0x00
		request:      9
		value:        u16(config_val)
		index:        0
		length:       0
	}

	self.usb_control_transfer(
		slot_id:     slot_id
		setup:       setup
		buffer_phys: 0
	)?
}

pub fn (mut self Xhci) get_device_descriptor(slot_id u8) ? {
	desc_virt, desc_phys := kernel_page_table.alloc_dma(1)
	defer { kernel_page_table.dealloc_dma(desc_virt, 1) }

	setup := SetupPacket{
		request_type: 0x80
		request:      6
		value:        0x0100
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
