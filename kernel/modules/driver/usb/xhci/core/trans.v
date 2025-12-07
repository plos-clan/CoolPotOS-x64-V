module core

import bus
import defs
import log

pub fn (mut self Xhci) submit_transfer(args bus.GeneralTransferArgs) ? {
	ep_num := args.ep_addr & 0x0f
	is_in := (args.ep_addr & defs.req_dir_in) != 0

	dci := if is_in { ep_num * 2 + 1 } else { ep_num * 2 }
	if dci < 2 || dci > 31 {
		return none
	}

	mut slot := &self.slots[args.slot_id]
	mut ring := &slot.rings[dci]

	trb := Trb.new_normal(args.buffer_phys, args.length)

	ring.enqueue(trb)
	self.doorbell.ring(args.slot_id, dci)
}

pub fn (mut self Xhci) submit_control(args bus.ControlTransferArgs) ? {
	is_in := (args.setup.request_type & defs.req_dir_in) != 0

	setup, slot_id := args.setup, args.slot_id
	setup_ptr := unsafe { &u32(&args.setup) }
	param_low := unsafe { setup_ptr[0] }
	param_high := unsafe { setup_ptr[1] }

	trt := match true {
		setup.length == 0 { u32(0) }
		is_in { 3 }
		else { 2 }
	}

	mut slot := &self.slots[slot_id]
	setup_trb := Trb.new_setup_stage(param_low, param_high, trt)
	slot.rings[1].enqueue(setup_trb)

	if setup.length > 0 {
		data_trb := Trb.new_data_stage(args.buffer_phys, setup.length, is_in)
		slot.rings[1].enqueue(data_trb)
	}

	status_dir_in := setup.length == 0 || !is_in
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

fn (mut self Xhci) complete_transfer(slot_id u8, dci u32, code u32, len u32) {
	mut slot := &self.slots[slot_id]

	if slot.usb_device == unsafe { nil } {
		return
	}

	ep_num := u8(dci / 2)
	is_in := (dci % 2) != 0

	status := match code {
		1 { bus.TransferStatus.completed }
		13 { .short_packet }
		4 { .babble }
		5 { .trb_error }
		6 { .stall }
		else { .unknown }
	}

	slot.usb_device.dispatch_completion(
		status:        status
		actual_length: len
		ep_addr:       if is_in { ep_num | defs.req_dir_in } else { ep_num }
	)
}
