# Limine V Template

This repository will demonstrate how to set up a basic x86-64 kernel in V using Limine.

## Notes

Vpm is broken we cannot submit new packages, so you have to fetch `limine` package manually.

```bash
v install --git https://github.com/wenxuanjun/v-limine
```

## Build

**The build system is simplified:**

- Can only build ISO image
- Assets (limine and OVMF) are not fetched from the internet

**Available targets:**
- `make`: Build the ISO image
- `make run`: Run the ISO image in QEMU
- `make clean`: Remove the build directory

You need to install `v`, `xorriso`, `make` to build the project, and `qemu` to boot the ISO.
