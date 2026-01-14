module log

pub fn success(fmt voidptr, ...) {
	print_(c'[\033[32mSUCCESS\033[0m] ')
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
}

pub fn info(fmt voidptr, ...) {
	print_(c'[\033[36mINFO\033[0m] ')
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
}

pub fn debug(fmt voidptr, ...) {
	print_(c'[\033[34mDEBUG\033[0m] ')
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
}

pub fn warn(fmt voidptr, ...) {
	print_(c'[\033[35mWARN\033[0m] ')
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
}

pub fn error(fmt voidptr, ...) {
	print_(c'[\033[31mERROR\033[0m] ')
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
}

pub fn print_(fmt voidptr, ...) {
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
}

pub fn println(fmt voidptr, ...) {
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
}

@[noreturn]
pub fn panic(fmt voidptr, ...) {
	print_(c'[\033[31mPANIC\033[0m] ')
	ap := C.va_list{}
	C.va_start(ap, fmt)
	vprint(fmt, ap)
	C.va_end(ap)
	print_(c'\n')
	for {}
}
