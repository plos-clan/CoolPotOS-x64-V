module mouse

const left_button = 1 << 0
const right_button = 1 << 1
const middle_button = 1 << 2
const always_one = 1 << 3
const x_sign = 1 << 4
const y_sign = 1 << 5
const x_overflow = 1 << 6
const y_overflow = 1 << 7

pub enum MouseAdditionalFlags {
	first_button
	second_button
	scroll_up
	scroll_down
	none
}

pub struct MousePacket {
mut:
	flags            u8
	additional_flags MouseAdditionalFlags = .none
	move_x           i16
	move_y           i16
}
