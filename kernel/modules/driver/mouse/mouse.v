@[has_globals]
module mouse

import sync { Queue }

__global (
  mouse Mouse
	mouse_queue Queue[MouseEvent]
)

pub enum MouseType {
	standard
	only_scroll
	five_button
}

pub struct Mouse {
	ports MousePorts
mut:
	mouse_type     MouseType = .standard
	packet_index   u8
	current_packet MousePacket
	button_states  [3]bool
}

pub fn init() ? {
	mouse.ports.send(0xf4)?
	mouse.mouse_type = mouse.identify_type()?
}

pub fn process_packet(packet u8) {
	modulo := match mouse.mouse_type {
		.standard { u8(3) }
		else { 4 }
	}

	match mouse.packet_index % modulo {
		0 {
			if packet & always_one == 0 {
				return
			}
			mouse.current_packet.flags = packet
		}
		1 { mouse.handle_movement(packet, true) }
		2 { mouse.handle_movement(packet, false) }
		3 { mouse.handle_additional_flags(packet) }
		else { return }
	}

	if mouse.packet_index % modulo == modulo - 1 {
		mouse.process_state()
	}

	mouse.packet_index = (mouse.packet_index + 1) % modulo
}

fn (self Mouse) identify_type() ?MouseType {
	self.ports.send(0xf2)
	for rate in [u8(200), 100, 80] {
		self.ports.send(0xf3)?
		self.ports.send(rate)?
	}
	self.ports.send(0xf2)?
	return match self.ports.read()? {
		0x03 { MouseType.only_scroll }
		0x04 { MouseType.five_button }
		else { MouseType.standard }
	}
}

fn (mut self Mouse) handle_movement(packet u8, is_x bool) {
	overflow, sign := if is_x {
		x_overflow, x_sign
	} else {
		y_overflow, y_sign
	}

	if self.current_packet.flags & overflow != 0 {
		return
	}

	delta := if self.current_packet.flags & sign != 0 {
		i16(u16(packet) | 0xff00)
	} else {
		i16(packet)
	}

	if is_x {
		self.current_packet.move_x = delta
	} else {
		self.current_packet.move_y = delta
	}
}

fn (mut self Mouse) handle_additional_flags(packet u8) {
	self.current_packet.additional_flags = match packet {
		0b0100_0001 { .first_button }
		0b0111_1111 { .second_button }
		0b0000_0001 { .scroll_up }
		0b1111_1111 | 0b0000_1111 { .scroll_down }
		else { .none }
	}
}

struct ButtonMapping {
	button MouseButton
	flag   u8
}

fn (mut self Mouse) process_state() {
	packet := &self.current_packet

	for i, mapping in [
		ButtonMapping{MouseButton.left, left_button},
		ButtonMapping{MouseButton.right, right_button},
		ButtonMapping{MouseButton.middle, middle_button},
	] {
		is_pressed := packet.flags & mapping.flag != 0

		if self.button_states[i] != is_pressed {
			if is_pressed {
				event := MouseEventPressed{mapping.button}
				mouse_queue.push(event)
			} else {
				event := MouseEventReleased{mapping.button}
				mouse_queue.push(event)
			}
			self.button_states[i] = is_pressed
		}
	}

	match packet.additional_flags {
		.scroll_up {
			event := MouseEventScroll{-1}
			mouse_queue.push(event)
		}
		.scroll_down {
			event := MouseEventScroll{1}
			mouse_queue.push(event)
		}
		else {}
	}

	if packet.move_x != 0 || packet.move_y != 0 {
		event := MouseEventMoved{packet.move_x, packet.move_y}
		mouse_queue.push(event)
	}
}
