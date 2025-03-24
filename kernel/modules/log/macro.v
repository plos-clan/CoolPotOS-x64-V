module log

pub fn print(fmt any, ...) {
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(voidptr(fmt), ap)
	C.va_end(ap)
}

pub fn success(fmt any, ...) {
	print(c"[\033[32mSUCCESS\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(voidptr(fmt), ap)
	C.va_end(ap)
}

pub fn info(fmt any, ...) {
	print(c"[\033[36mINFO\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(voidptr(fmt), ap)
	C.va_end(ap)
}

pub fn debug(fmt any, ...) {
	print(c"[\033[34mDEBUG\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(voidptr(fmt), ap)
	C.va_end(ap)
}

pub fn warn(fmt any, ...) {
	print(c"[\033[35mWARN\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(voidptr(fmt), ap)
	C.va_end(ap)
}

pub fn error(fmt any, ...) {
	print(c"[\033[31mERROR\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(voidptr(fmt), ap)
	C.va_end(ap)
}
