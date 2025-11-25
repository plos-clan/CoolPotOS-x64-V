module core

@[packed]
pub struct ErstEntry {
pub mut:
	base_addr u64
	size      u32
	reserved  u32
}
