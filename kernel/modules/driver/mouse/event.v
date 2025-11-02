module mouse

pub enum MouseButton {
	left
	right
	middle
}

pub struct MouseEventMoved {
pub mut:
	dx i16
	dy i16
}

pub struct MouseEventScroll {
pub mut:
	delta i8
}

pub struct MouseEventPressed {
pub mut:
	button MouseButton
}

pub struct MouseEventReleased {
pub mut:
	button MouseButton
}

pub type MouseEvent = MouseEventMoved
	| MouseEventScroll
	| MouseEventPressed
	| MouseEventReleased
