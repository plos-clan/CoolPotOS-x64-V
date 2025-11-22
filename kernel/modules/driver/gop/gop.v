@[has_globals]
module gop

import limine

@[_linker_section: '.limine_requests']
@[cinit]
__global (
	volatile framebuffer_request = limine.FramebufferRequest{
		response: unsafe { nil }
	}
)

__global (
	framebuffer &limine.Framebuffer
)

pub fn init() {
	response := &framebuffer_request.response
	framebuffer = unsafe { response.framebuffers[0] }
}
