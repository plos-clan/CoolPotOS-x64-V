module utils

pub fn ilog2[T](v T) T {
	mut val := v
	mut r := T(0)
	for (val >> 1) > 0 {
		val >>= 1
		r++
	}
	return r
}
