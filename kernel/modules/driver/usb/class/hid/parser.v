module hid

import log
import utils { HashMap, Vec }

const item_type_main = 0
const item_type_global = 1
const item_type_local = 2

const tag_input = 0b1000
const tag_output = 0b1001
const tag_collection = 0b1010
const tag_feature = 0b1011
const tag_end_collection = 0b1100

const tag_usage_page = 0b0000
const tag_logical_min = 0b0001
const tag_logical_max = 0b0010
const tag_physical_min = 0b0011
const tag_physical_max = 0b0100
const tag_unit_exp = 0b0101
const tag_unit = 0b0110
const tag_report_size = 0b0111
const tag_report_id = 0b1000
const tag_report_count = 0b1001
const tag_push = 0b1010
const tag_pop = 0b1011

const tag_usage = 0b0000
const tag_usage_min = 0b0001
const tag_usage_max = 0b0010

pub const flag_constant = 1 << 0
pub const flag_variable = 1 << 1
pub const flag_relative = 1 << 2
pub const flag_wrap = 1 << 3
pub const flag_nonlinear = 1 << 4
pub const flag_no_pref = 1 << 5
pub const flag_null_state = 1 << 6
pub const flag_volatile = 1 << 7
pub const flag_buffered = 1 << 8

pub enum HidKind as u8 {
	input   = 0
	output  = 1
	feature = 2
}

pub struct HidField {
pub:
	report_id    u8
	kind         HidKind
	bit_offset   u32
	bit_size     u32
	report_count u32
	logical_min  i32
	logical_max  i32
	physical_min i32
	physical_max i32
	flags        u32
	usage_page   u16
	usage_min    u32
	usage_max    u32
}

pub fn (f &HidField) is_const() bool {
	return (f.flags & flag_constant) != 0
}

pub fn (f &HidField) is_variable() bool {
	return (f.flags & flag_variable) != 0
}

pub fn (f &HidField) is_array() bool {
	return (f.flags & flag_variable) == 0
}

pub fn (f &HidField) is_relative() bool {
	return (f.flags & flag_relative) != 0
}

pub fn (f &HidField) is_range() bool {
	return f.usage_min != f.usage_max
}

pub fn (f &HidField) value(data &u8, idx u32) u32 {
	offset := f.bit_offset + (idx * f.bit_size)
	byte_idx := offset / 8
	shift := offset % 8

	count := (offset + f.bit_size + 7) / 8 - byte_idx
	mut raw := u64(0)
	for i in 0 .. count {
		raw |= u64(unsafe { data[byte_idx + i] }) << (i * 8)
	}
	return u32((raw >> shift) & ((u64(1) << f.bit_size) - 1))
}

pub fn (f &HidField) value_signed(data &u8, idx u32) i32 {
	val := f.value(data, idx)

	if f.bit_size >= 32 {
		return i32(val)
	}

	shift := 32 - f.bit_size
	return i32(val << shift) >> shift
}

pub struct HidReport {
pub mut:
	id        u8
	size_bits [3]u32
	fields    Vec[HidField]
}

pub fn (r &HidReport) size_bytes(kind HidKind) u32 {
	idx := int(kind)
	return (r.size_bits[idx] + 7) / 8
}

pub struct HidDescriptor {
pub mut:
	reports HashMap[u8, HidReport]
}

pub fn (mut d HidDescriptor) free() {
	d.reports.free()
}

struct LocalItem {
	is_range bool
	min      u32
mut:
	max u32
}

struct LocalState {
mut:
	items Vec[LocalItem]
}

struct GlobalState {
mut:
	usage_page   u16
	logical_min  i32
	logical_max  i32
	physical_min i32
	physical_max i32
	report_size  u32
	report_count u32
	report_id    u8
}

pub struct HidParser {
	data   &u8
	length u16
mut:
	offset       u16
	global       GlobalState
	global_stack Vec[GlobalState]
	local        LocalState
	descriptor   HidDescriptor
}

pub fn HidParser.new(data &u8, len u16) HidParser {
	return HidParser{
		data:   unsafe { data }
		length: len
	}
}

pub fn (mut p HidParser) parse() ?HidDescriptor {
	for p.offset < p.length {
		header := unsafe { p.data[p.offset] }
		p.offset++

		size_code := header & 0x03
		data_len := if size_code == 3 { u16(4) } else { size_code }

		item_type := (header >> 2) & 0x03
		item_tag := (header >> 4) & 0x0f

		if p.offset + data_len > p.length {
			log.warn(c'HID: Truncated at offset %d', p.offset)
			break
		}

		match item_type {
			item_type_main {
				flags := p.read_unsigned(data_len)
				p.handle_main(item_tag, flags)
			}
			item_type_global {
				p.handle_global(item_tag, data_len)
			}
			item_type_local {
				val := p.read_unsigned(data_len)
				p.handle_local(item_tag, data_len, val)
			}
			else {}
		}
	}

	return p.descriptor
}

fn (mut p HidParser) handle_global(tag u8, len u16) {
	match tag {
		tag_usage_page {
			p.global.usage_page = u16(p.read_unsigned(len))
		}
		tag_logical_min {
			p.global.logical_min = p.read_signed(len)
		}
		tag_logical_max {
			p.global.logical_max = p.read_signed(len)
		}
		tag_physical_min {
			p.global.physical_min = p.read_signed(len)
		}
		tag_physical_max {
			p.global.physical_max = p.read_signed(len)
		}
		tag_report_size {
			p.global.report_size = p.read_unsigned(len)
		}
		tag_report_count {
			p.global.report_count = p.read_unsigned(len)
		}
		tag_report_id {
			p.global.report_id = u8(p.read_unsigned(len))
		}
		tag_push {
			p.global_stack.push(p.global)
		}
		tag_pop {
			if state := p.global_stack.pop() {
				p.global = state
			} else {
				log.warn(c'HID: Global stack pop underflow')
			}
		}
		else {
			p.offset += len
		}
	}
}

fn (mut p HidParser) handle_local(tag u8, data_len u16, val u32) {
	is_extended := data_len == 4

	full_usage := if is_extended {
		val
	} else {
		(u32(p.global.usage_page) << 16) | val
	}

	match tag {
		tag_usage {
			p.local.items.push(LocalItem{
				is_range: false
				min:      full_usage
				max:      full_usage
			})
		}
		tag_usage_min {
			p.local.items.push(LocalItem{
				is_range: true
				min:      full_usage
				max:      0
			})
		}
		tag_usage_max {
			if mut last := p.local.items.last() {
				last.max = full_usage
			}
		}
		else {}
	}
}

fn (mut p HidParser) handle_main(tag u8, flags u32) {
	defer { p.local.items.clear() }

	kind := match tag {
		tag_input { HidKind.input }
		tag_output { .output }
		tag_feature { .feature }
		else { return }
	}

	kind_idx := int(kind)
	report_id := p.global.report_id

	mut new_report := HidReport{
		id: report_id
	}
	if report_id != 0 {
		new_report.size_bits[0] = 8
		new_report.size_bits[1] = 8
		new_report.size_bits[2] = 8
	}

	mut layout := p.descriptor.reports.ensure(report_id, new_report)

	report_count := p.global.report_count
	report_size := p.global.report_size
	is_variable := (flags & flag_variable) != 0
	is_single_range := p.local.items.len == 1 && p.local.items.get(0).is_range

	if !is_variable && is_single_range {
		usage_item := p.local.items.get(0)
		layout.fields.push(HidField{
			report_id:    report_id
			kind:         kind
			bit_offset:   layout.size_bits[kind_idx]
			bit_size:     report_size
			report_count: report_count
			logical_min:  p.global.logical_min
			logical_max:  p.global.logical_max
			physical_min: p.global.physical_min
			physical_max: p.global.physical_max
			flags:        flags
			usage_page:   p.global.usage_page
			usage_min:    usage_item.min
			usage_max:    usage_item.max
		})
		layout.size_bits[kind_idx] += report_size * report_count
	} else {
		mut item_idx := u64(0)
		mut range_offset := u32(0)
		for _ in 0 .. report_count {
			mut current_usage := u32(0)
			if item := p.local.items.try_get(item_idx) {
				current_usage = item.min + range_offset
				if current_usage < item.max {
					range_offset++
				} else if item_idx < p.local.items.len - 1 {
					item_idx++
					range_offset = 0
				}
			}
			layout.fields.push(HidField{
				report_id:    report_id
				kind:         kind
				bit_offset:   layout.size_bits[kind_idx]
				bit_size:     report_size
				report_count: 1
				logical_min:  p.global.logical_min
				logical_max:  p.global.logical_max
				physical_min: p.global.physical_min
				physical_max: p.global.physical_max
				flags:        flags
				usage_page:   p.global.usage_page
				usage_min:    current_usage
				usage_max:    current_usage
			})
			layout.size_bits[kind_idx] += report_size
		}
	}
}

fn (mut p HidParser) read_signed(len u16) i32 {
	value_u := p.read_unsigned(len)
	return match len {
		1 { i32(i8(value_u)) }
		2 { i32(i16(value_u)) }
		4 { i32(value_u) }
		else { 0 }
	}
}

fn (mut p HidParser) read_unsigned(len u16) u32 {
	mut value := u32(0)
	match len {
		1 {
			value = unsafe { u32(p.data[p.offset]) }
		}
		2 {
			b0 := unsafe { u32(p.data[p.offset]) }
			b1 := unsafe { u32(p.data[p.offset + 1]) }
			value = b0 | (b1 << 8)
		}
		4 {
			b0 := unsafe { u32(p.data[p.offset]) }
			b1 := unsafe { u32(p.data[p.offset + 1]) }
			b2 := unsafe { u32(p.data[p.offset + 2]) }
			b3 := unsafe { u32(p.data[p.offset + 3]) }
			value = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
		}
		else {}
	}

	p.offset += len
	return value
}
