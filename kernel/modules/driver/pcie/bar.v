module pcie

$if amd64 {
	import arch.amd64.cpu { mmio_in, mmio_out }
} $else {
	import arch.loongarch64.cpu { mmio_in, mmio_out }
}

pub enum BarType {
	io
	memory32
	memory64
}

pub struct PciBar {
pub:
	bar_type     BarType
	address      u64
	size         u64
	prefetchable bool
}

pub fn PciBar.scan(base u64) [6]PciBar {
	mut bars := [6]PciBar{}
	mut skip_next := false

	for i in 0 .. 6 {
		if skip_next {
			skip_next = false
			continue
		}

		offset := u64(0x10) + (u64(i) * 4)
		reg_ptr := unsafe { &u32(base + offset) }

		val_low := mmio_in[u32](reg_ptr)

		if val_low == 0 {
			continue
		}

		mmio_out[u32](reg_ptr, 0xFFFF_FFFF)
		mask_low := mmio_in[u32](reg_ptr)
		mmio_out[u32](reg_ptr, val_low)

		is_io := (val_low & 1) != 0
		is_64bit := !is_io && (val_low & 0x07) == 0x04
		is_pref := !is_io && (val_low & 0x08) != 0

		if is_64bit {
			high_ptr := unsafe { &u32(base + offset + 4) }
			val_high := mmio_in[u32](high_ptr)

			mmio_out[u32](high_ptr, 0xFFFF_FFFF)
			mask_high := mmio_in[u32](high_ptr)
			mmio_out[u32](high_ptr, val_high)

			mem_mask := ~u32(0xF)
			address := (u64(val_high) << 32) | u64(val_low & mem_mask)
			encoded_mask := (u64(mask_high) << 32) | u64(mask_low & mem_mask)
			size := ~encoded_mask + 1

			bars[i] = PciBar{
				bar_type:     .memory64
				address:      address
				size:         size
				prefetchable: is_pref
			}

			skip_next = true
		} else {
			if is_io {
				io_mask := ~u32(0x3)
				address := u64(val_low & io_mask)
				size := u64(~(mask_low & io_mask) + 1)

				bars[i] = PciBar{
					bar_type:     .io
					address:      address
					size:         size
					prefetchable: false
				}
			} else {
				mem_mask := ~u32(0xF)
				address := u64(val_low & mem_mask)
				size := u64(~(mask_low & mem_mask) + 1)

				bars[i] = PciBar{
					bar_type:     .memory32
					address:      address
					size:         size
					prefetchable: is_pref
				}
			}
		}
	}

	return bars
}
