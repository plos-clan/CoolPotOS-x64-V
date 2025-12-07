ARCH ?= x86_64
BUILD_DIR = build
OUTPUT_IMG = $(BUILD_DIR)/CoolPotOS-$(ARCH).img

CFLAGS = -w -O3 -I./kernel/c -Ilibs -g -nostdinc -fno-builtin
CFLAGS += -ffunction-sections -fdata-sections -fno-stack-protector

VFLAGS = -w -manualfree -gc none -no-builtin -no-preludes
VFLAGS += -nofloat -d no_backtrace -no-bounds-checking

LDFLAGS = -nostdlib -static --gc-sections -T assets/linkers/$(ARCH).ld
LDFLAGS += -Llibs/$(ARCH) -los_terminal -lalloc

QEMUFLAGS = -no-reboot -serial stdio
QEMUFLAGS += -drive if=pflash,format=raw,file=assets/firmware/$(ARCH).fd
QEMUFLAGS += -device nvme,drive=disk,serial=deadbeef
QEMUFLAGS += -device qemu-xhci -device usb-kbd -device usb-mouse
QEMUFLAGS += -netdev user,id=net0 -device usb-net,netdev=net0
QEMUFLAGS += -drive if=none,id=disk,format=raw,file=$(OUTPUT_IMG)

ifeq ($(ARCH), x86_64)
	CFLAGS += -target x86_64-unknown-none
	CFLAGS += -mcmodel=kernel -mgeneral-regs-only -mno-red-zone
	QEMUFLAGS += -M q35 -cpu qemu64,+x2apic -enable-kvm
	QEMUFLAGS += -audiodev pa,id=snd -machine pcspk-audiodev=snd
	VFLAGS += -arch amd64
	EFI_NAME := BOOTX64.EFI
else ifeq ($(ARCH), loongarch64)
	CFLAGS += -target loongarch64-unknown-none
	CFLAGS += -mcmodel=medium -msoft-float
	QEMUFLAGS += -M virt -cpu la464 -device ramfb
	VFLAGS += -arch loongarch64
	EFI_NAME := BOOTLOONGARCH64.EFI
else
	$(error Unsupported architecture: $(ARCH))
endif

.PHONY: default kernel image run clean

default: image

run: image
	@qemu-system-$(ARCH) $(QEMUFLAGS)

clean:
	@rm -rf $(BUILD_DIR)

kernel:
	@mkdir -p $(BUILD_DIR)
	@v $(VFLAGS) -o $(BUILD_DIR)/blob.c kernel
	@clang $(CFLAGS) -c $(BUILD_DIR)/blob.c -o $(BUILD_DIR)/blob.o
	@ld.lld $(BUILD_DIR)/blob.o $(LDFLAGS) -o $(BUILD_DIR)/kernel

image: kernel
	@chmod +x assets/tools/oib
	@assets/tools/oib -o $(OUTPUT_IMG) -f $(BUILD_DIR)/kernel:kernel \
		-f assets/limine/limine.conf:limine.conf \
		-f assets/limine/$(EFI_NAME):efi/boot/$(EFI_NAME)
