module mem

import limine
import log

@[_linker_section: '.requests']
@[cinit]
__global (
	volatile memmap_request = limine.MemmapRequest{
		response: unsafe { nil }
	}
)

__global (
	frame_allocator FrameAllocator
)

struct FrameAllocator {
mut:
	bitmap        Bitmap
	origin_frames usize
	usable_frames usize
}

pub fn init_frame() {
	memory_map := memmap_request.response

	mut memory_size := u64(0)
	for i := memory_map.entry_count - 1; i >= 0; i-- {
		region := unsafe { memory_map.entries[i] }
		if region.@type == 0 {
			memory_size = region.base + region.length
			break
		}
	}

	bitmap_size := (memory_size / 4096 + 7) / 8

	mut bitmap_address := u64(-1)
	for i := 0; i < memory_map.entry_count; i++ {
		region := unsafe { memory_map.entries[i] }
		if region.@type == 0 && region.length >= bitmap_size {
			bitmap_address = region.base
			break
		}
	}

	if bitmap_address == u64(-1) {
		return
	}

	mut bitmap:= Bitmap.init(&u8(phys_to_virt(bitmap_address)), bitmap_size)

	mut origin_frames := u64(0)
	for i := 0; i < memory_map.entry_count; i++ {
		region := unsafe { memory_map.entries[i] }
		if region.@type == 0 {
			start_frame := region.base / 4096
			frame_count := region.length / 4096
			origin_frames += frame_count
			bitmap.set_range(start_frame, start_frame + frame_count, true)
		}
	}

	bitmap_frame_start := bitmap_address / 4096
	bitmap_frame_count := (bitmap_size + 4095) / 4096
	bitmap.set_range(bitmap_frame_start, bitmap_frame_start + bitmap_frame_count, false)

	frame_allocator = FrameAllocator{
		bitmap: bitmap,
		origin_frames: origin_frames,
		usable_frames: origin_frames - bitmap_frame_count
	}

	available_memory := origin_frames / 256
	log.info(c'Available memory: %lld MiB\n', available_memory)
}

pub fn alloc_frames(count usize) ?usize {
	mut bitmap := &frame_allocator.bitmap
	frame_index := bitmap.find_range(count, true)?

	bitmap.set_range(frame_index, frame_index + count, false)
	frame_allocator.usable_frames -= count

	return frame_index * 4096
}
