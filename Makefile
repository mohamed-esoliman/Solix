#
# Solix build Makefile (real, bootable)
PROJECT_NAME := Solix
VERSION := 1.0

MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

ROOT := $(CURDIR)
KERNEL_DIR := kernel
BUSYBOX_DIR := busybox
ROOTFS_SRC := rootfs
BUILD_DIR := build
OUT_DIR := out

KERNEL_VER := 6.6.8
KERNEL_IMAGE := $(BUILD_DIR)/boot/vmlinuz-$(KERNEL_VER)-solix
KERNEL_SYMLINK := $(BUILD_DIR)/boot/vmlinuz

BUSYBOX_INSTALL := $(BUSYBOX_DIR)/_install

SHELL_SRC := $(ROOTFS_SRC)/shell/shell.c
SHELL_BIN := $(BUILD_DIR)/rootfs/bin/shell
INIT_SCRIPT := $(ROOTFS_SRC)/etc/init.d/rcS

INITRAMFS_IMG := $(BUILD_DIR)/initramfs.img
ROOTFS_IMG := $(BUILD_DIR)/rootfs.img

ISO_DIR := iso
ISO_FILE := $(OUT_DIR)/solix-$(VERSION).iso

.PHONY: all kernel busybox shell initramfs iso run run-persistent rootfsimg utils test clean distclean ensure-dirs

all: ensure-dirs kernel busybox shell initramfs iso
	@echo "Built $(ISO_FILE)"

help:
	@echo "Targets: all, kernel, busybox, shell, initramfs, iso, run, clean, distclean"

banner:
	@true

info:
	@echo "Building $(PROJECT_NAME) $(VERSION)"

toolchain:
	@echo "No cross-toolchain needed for this build."

kernel: ensure-dirs
	@cd $(KERNEL_DIR) && bash ./build-kernel.sh $(KERNEL_VER) $(abspath $(BUILD_DIR))

busybox:
	@cd $(BUSYBOX_DIR) && bash ./build-busybox.sh

shell: ensure-dirs
	@echo "Compiling custom Solix shell (static)..."
	@mkdir -p $(BUILD_DIR)/rootfs/bin
	@CC_BIN=$$(command -v musl-gcc || echo cc); \
	$$CC_BIN -static -s -O2 -o $(SHELL_BIN) $(SHELL_SRC)

utils: ensure-dirs
	@echo "Building static utils..."
	@mkdir -p $(BUILD_DIR)/rootfs/bin
	@CC_BIN=$$(command -v musl-gcc || echo gcc); \
	$$CC_BIN -static -Os -o $(BUILD_DIR)/rootfs/bin/uptime_lite rootfs/utils/uptime_lite.c || (echo "Note: static link failed; retrying non-static" && $$CC_BIN -Os -o $(BUILD_DIR)/rootfs/bin/uptime_lite rootfs/utils/uptime_lite.c)
	@CC_BIN=$$(command -v musl-gcc || echo gcc); \
	$$CC_BIN -static -Os -o $(BUILD_DIR)/rootfs/bin/ps_lite rootfs/utils/ps_lite.c || (echo "Note: static link failed; retrying non-static" && $$CC_BIN -Os -o $(BUILD_DIR)/rootfs/bin/ps_lite rootfs/utils/ps_lite.c)
	@CC_BIN=$$(command -v musl-gcc || echo gcc); \
	$$CC_BIN -static -Os -o $(BUILD_DIR)/rootfs/bin/meminfo_lite rootfs/utils/meminfo_lite.c || (echo "Note: static link failed; retrying non-static" && $$CC_BIN -Os -o $(BUILD_DIR)/rootfs/bin/meminfo_lite rootfs/utils/meminfo_lite.c)

init: 
	@test -f $(INIT_SCRIPT)

grub:
	@true

initramfs: ensure-dirs kernel busybox shell init
	@bash $(ISO_DIR)/build-initramfs.sh $(abspath $(BUILD_DIR)) $(abspath $(BUSYBOX_INSTALL)) $(abspath $(ROOTFS_SRC))

rootfsimg: busybox shell utils
	@bash scripts/mkrootfs.sh

iso: ensure-dirs initramfs
	@bash $(ISO_DIR)/build-iso.sh $(abspath $(BUILD_DIR)) $(abspath $(OUT_DIR)) $(VERSION)

run: initramfs
	@echo "Launching QEMU..."
	@qemu-system-x86_64 -kernel $(KERNEL_SYMLINK) -initrd $(INITRAMFS_IMG) -m 512M -nographic -serial mon:stdio -append "console=ttyS0 quiet"

run-persistent: initramfs rootfsimg
	@echo "Launching QEMU with persistent disk..."
	@qemu-system-x86_64 -m 512M -cpu max -nographic -serial mon:stdio \
	  -kernel $(KERNEL_SYMLINK) \
	  -initrd $(INITRAMFS_IMG) \
	  -append "console=ttyS0 root=/dev/vda rw" \
	  -drive file=$(ROOTFS_IMG),if=virtio,format=raw

# Quick test without full build
test:
	@echo "Running smoke boot test (20s)..."
	@timeout 20s qemu-system-x86_64 -kernel $(KERNEL_SYMLINK) -initrd $(INITRAMFS_IMG) -m 512M -nographic -serial mon:stdio -append "console=ttyS0" 2>&1 | tee $(BUILD_DIR)/qemu.log | grep -E "\[solix\] rcS starting|Solix login|\[solix\] launching custom shell" >/dev/null

# Development targets
.PHONY: dev-shell dev-kernel dev-iso
dev-shell:
	@echo -e "$(BLUE)[INFO]$(NC) Quick shell rebuild..."
	@make shell
	@echo -e "$(GREEN)[SUCCESS]$(NC) Shell rebuilt"

dev-kernel:
	@echo -e "$(BLUE)[INFO]$(NC) Quick kernel rebuild..."
	@make kernel
	@echo -e "$(GREEN)[SUCCESS]$(NC) Kernel rebuilt"

dev-iso:
	@echo -e "$(BLUE)[INFO]$(NC) Quick ISO rebuild..."
	@make iso
	@echo -e "$(GREEN)[SUCCESS]$(NC) ISO rebuilt"

# Check dependencies
.PHONY: check-deps
check-deps:
	@echo -e "$(BLUE)[INFO]$(NC) Checking build dependencies..."
	@missing_tools=(); \
	for tool in gcc make git wget tar gzip; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			missing_tools+=($$tool); \
		fi; \
	done; \
	if [ $${#missing_tools[@]} -ne 0 ]; then \
		echo -e "$(RED)[ERROR]$(NC) Missing required tools: $${missing_tools[*]}"; \
		echo -e "$(YELLOW)Install with your package manager:$(NC)"; \
		echo -e "  Ubuntu/Debian: sudo apt install build-essential git wget"; \
		echo -e "  RHEL/CentOS: sudo dnf groupinstall 'Development Tools'"; \
		echo -e "  macOS: xcode-select --install"; \
		exit 1; \
	else \
		echo -e "$(GREEN)[SUCCESS]$(NC) All required tools found"; \
	fi

clean:
	@rm -rf $(BUILD_DIR) $(OUT_DIR)

distclean: clean
	@rm -rf $(KERNEL_DIR)/downloads $(BUSYBOX_DIR)/downloads

status:
	@echo "Kernel: $(KERNEL_IMAGE)"; test -f $(KERNEL_IMAGE) && echo OK || echo MISSING
	@echo "Shell:  $(SHELL_BIN)"; test -f $(SHELL_BIN) && echo OK || echo MISSING
	@echo "Initrd: $(INITRAMFS_IMG)"; test -f $(INITRAMFS_IMG) && echo OK || echo MISSING
	@echo "ISO:    $(ISO_FILE)"; test -f $(ISO_FILE) && echo OK || echo MISSING

success:
	@true

docs:
	@true

parallel:
	@$(MAKE) -j$$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) all

rebuild: clean all

quick: all

install-deps:
	@echo "Use Dockerfile to build in a container."

ensure-dirs:
	@mkdir -p $(BUILD_DIR)/boot $(BUILD_DIR)/rootfs/{bin,sbin,etc,proc,sys,dev,tmp,usr/bin} $(OUT_DIR)
	@mkdir -p rootfs/utils rootfs/etc/init.d rootfs/etc

# Mark targets that don't create files
.PHONY: all help banner info toolchain binutils gcc glibc kernel shell init grub iso test test-quick
.PHONY: dev-shell dev-kernel dev-iso check-deps clean clean-toolchain clean-kernel clean-iso distclean
.PHONY: status success docs parallel rebuild quick install-deps 