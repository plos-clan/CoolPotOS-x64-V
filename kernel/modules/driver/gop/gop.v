module gop

import limine

@[_linker_section: '.requests']
@[cinit]
__global (
	volatile framebuffer_request = limine.FramebufferRequest{
		response: unsafe { nil }
	}
)

__global (
	framebuffer &limine.Framebuffer
)

pub fn get_framebuffer() &limine.Framebuffer {
	return framebuffer
}

pub fn init() {
	if framebuffer_request.response == unsafe { nil } {
		for {}
	}

	framebuffer = unsafe { framebuffer_request.response.framebuffers[0] }

	width := framebuffer.width
	height := framebuffer.height

	stride := framebuffer.pitch / 4
	mut slice := &u32(framebuffer.address)

	for i := u64(0); i < width; i++ {
		for j := u64(0); j < height; j++ {
			unsafe { slice[j * stride + i] = 0xffffff }
		}
	}
}
