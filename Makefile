override IMAGE_NAME := template
BUILD_DIR = build
ISO_DIR = $(BUILD_DIR)/iso_img

CCACHE_EXISTS := $(shell which ccache 2> /dev/null)
ifdef CCACHE_EXISTS
    CC := ccache clang
else
    CC := clang
endif

CFLAGS = -w -m64 -O3 -I./kernel/c -Ilibs -g
CFLAGS += -ffunction-sections -fdata-sections -fno-stack-protector
CFLAGS += -mno-80387 -mno-mmx -mno-sse -mno-sse2 -mno-red-zone
VFLAGS = -manualfree -gc none -enable-globals -nofloat -d no_backtrace

LDFLAGS = -nostdlib -static -gc-sections -T assets/linker.ld
LDFLAGS += -Llibs -los_terminal -lalloc

XORRISOFLAGS = -as mkisofs --efi-boot limine-uefi-cd.bin
QEMUFLAGS = -M q35 -cpu qemu64,+x2apic -no-reboot -serial stdio -enable-kvm
QEMUFLAGS += -drive if=pflash,format=raw,file=assets/ovmf-code.fd

.PHONY: default setup kernel image clean

default: image

# Create build directories
setup:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(ISO_DIR)
	@cp -r assets/limine/* $(ISO_DIR)/

# Compile V to C and link to kernel
kernel: setup
	@v $(VFLAGS) -o $(BUILD_DIR)/blob.c kernel
	@$(CC) $(CFLAGS) -c $(BUILD_DIR)/blob.c -o $(BUILD_DIR)/blob.o
	@ld $(BUILD_DIR)/blob.o $(LDFLAGS) -o $(BUILD_DIR)/kernel
	@cp $(BUILD_DIR)/kernel $(ISO_DIR)/kernel

# Create ISO image
image: kernel
	@xorriso $(XORRISOFLAGS) $(ISO_DIR) -o $(BUILD_DIR)/$(IMAGE_NAME).iso 2> /dev/null
	@echo "Image created: $(BUILD_DIR)/$(IMAGE_NAME).iso"

# Boot ISO image in QEMU
run: image
	@qemu-system-x86_64 $(QEMUFLAGS) $(BUILD_DIR)/$(IMAGE_NAME).iso

# Clean build artifacts
clean:
	@rm -rf $(BUILD_DIR)
