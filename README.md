# CoolPotOS x64 V

This is a simple operating system for `x86_64` and `loongarch64` written in V.

## Build

Fetch `limine` dependency:

```bash
v install https://github.com/wenxuanjun/v-limine
```

**Available targets:**
- `make`: Build the ISO image
- `make run`: Build and run the ISO image in QEMU
- `make clean`: Remove the build directory

Use `ARCH=x86_64` or `ARCH=loongarch64` to specify the architecture.

## License

The project follows MIT license. Anyone can use it for free. See [LICENSE](LICENSE).
