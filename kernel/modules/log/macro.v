module log

pub fn print(fmt voidptr, ...) {
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}

pub fn success(fmt voidptr, ...) {
	print(c"[\033[32mSUCCESS\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}

pub fn info(fmt voidptr, ...) {
	print(c"[\033[36mINFO\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}

pub fn debug(fmt voidptr, ...) {
	print(c"[\033[34mDEBUG\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}

pub fn warn(fmt voidptr, ...) {
	print(c"[\033[35mWARN\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}

pub fn error(fmt voidptr, ...) {
	print(c"[\033[31mERROR\033[0m] ")
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}
