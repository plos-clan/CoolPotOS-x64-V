module mem

pub struct Bitmap {
mut:
	buffer &u8
	length usize
}

pub fn Bitmap.init(buffer &u8, size usize) Bitmap {
	unsafe {
		bitmap := Bitmap{
			buffer: buffer
			length: size * 8
		}
		C.memset(buffer, 0, size)
		return bitmap
	}
}

pub fn (bitmap Bitmap) get(index usize) bool {
	word_index := index / 8
	bit_index := index % 8

	unsafe {
		return ((bitmap.buffer[word_index] >> bit_index) & 1) == 1
	}
}

pub fn (mut bitmap Bitmap) set(index usize, value bool) {
	word_index := index / 8
	bit_index := index % 8

	unsafe {
		if value {
			bitmap.buffer[word_index] |= (u8(1) << bit_index)
		} else {
			bitmap.buffer[word_index] &= ~(u8(1) << bit_index)
		}
	}
}

pub fn (mut bitmap Bitmap) set_range(start usize, end usize, value bool) {
	if start >= end || start >= bitmap.length {
		return
	}

	start_word := (start + 7) / 8
	end_word := end / 8

	for i := start; i < start_word * 8 && i < end; i++ {
		bitmap.set(i, value)
	}

	if start_word > end_word {
		return
	}

	if start_word <= end_word {
		fill_value := if value { u8(-1) } else { 0 }
		for i := start_word; i < end_word; i++ {
			unsafe {
				bitmap.buffer[i] = fill_value
			}
		}
	}

	for i := end_word * 8; i < end; i++ {
		bitmap.set(i, value)
	}
}

pub fn (bitmap Bitmap) find_range(length usize, value bool) ?usize {
	mut count := usize(0)
	mut start_index := usize(0)

	byte_match := if value { u8(-1) } else { 0 }
	byte_match_rev := if value { 0 } else { u8(-1) }

	for byte_idx := usize(0); byte_idx < bitmap.length / 8; byte_idx++ {
		byte_ := unsafe { bitmap.buffer[byte_idx] }
		if byte_ == byte_match_rev {
			count = 0
		} else if byte_ == byte_match {
			if length < 8 {
				return byte_idx * 8
			}
			if count == 0 {
				start_index = byte_idx * 8
			}
			count += 8
			if count >= length {
				return start_index
			}
		} else {
			for bit := usize(0); bit < 8; bit++ {
				bit_value := (byte_ >> bit) & 1 == 1
				if bit_value == value {
					if count == 0 {
						start_index = byte_idx * 8 + bit
					}
					count++
					if count == length {
						return start_index
					}
				} else {
					count = 0
				}
			}
		}
	}
	return none
}
