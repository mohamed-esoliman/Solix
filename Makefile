#
# Solix Custom Linux Makefile
# Part of the Solix custom Linux build
#
# Copyright (c) 2024 Mohamed Soliman
# Licensed under the MIT License
#
# This Makefile orchestrates the entire build process for Solix,
# from toolchain compilation to ISO generation.
#

# Project information
PROJECT_NAME = Solix
VERSION = 1.0
DESCRIPTION = Custom Linux From Scratch project

# Build configuration
MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

# Directories
TOOLCHAIN_DIR = toolchain
KERNEL_DIR = kernel
ROOTFS_DIR = rootfs
GRUB_DIR = grub
ISO_DIR = iso
SCRIPTS_DIR = scripts

# Build products
ISO_FILE = $(ISO_DIR)/solix-$(VERSION).iso
KERNEL_IMAGE = $(ROOTFS_DIR)/boot/vmlinuz
SHELL_BINARY = $(ROOTFS_DIR)/bin/shell
INIT_SCRIPT = $(ROOTFS_DIR)/etc/init.d/rcS

# Tool locations
BINUTILS_SCRIPT = $(TOOLCHAIN_DIR)/build-binutils.sh
GCC_SCRIPT = $(TOOLCHAIN_DIR)/build-gcc.sh
GLIBC_SCRIPT = $(TOOLCHAIN_DIR)/build-glibc.sh
KERNEL_SCRIPT = $(KERNEL_DIR)/build-kernel.sh
GRUB_SCRIPT = $(GRUB_DIR)/build-grub.sh
ISO_SCRIPT = $(ISO_DIR)/make-iso.sh

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
PURPLE = \033[0;35m
CYAN = \033[0;36m
NC = \033[0m

# Default target
.PHONY: all
all: banner info toolchain kernel shell init grub iso success

# Help target
.PHONY: help
help:
	@echo -e "$(BLUE)╔══════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(BLUE)║                    Solix Build System                       ║$(NC)"
	@echo -e "$(BLUE)║                     Version $(VERSION)                           ║$(NC)"
	@echo -e "$(BLUE)╚══════════════════════════════════════════════════════════════╝$(NC)"
	@echo
	@echo -e "$(GREEN)Available targets:$(NC)"
	@echo -e "  $(CYAN)all$(NC)         - Build complete Solix system (default)"
	@echo -e "  $(CYAN)toolchain$(NC)   - Build cross-compilation toolchain"
	@echo -e "  $(CYAN)kernel$(NC)      - Compile Linux kernel with Solix config"
	@echo -e "  $(CYAN)shell$(NC)       - Compile custom Solix shell"
	@echo -e "  $(CYAN)init$(NC)        - Verify init system"
	@echo -e "  $(CYAN)grub$(NC)        - Setup GRUB bootloader"
	@echo -e "  $(CYAN)iso$(NC)         - Generate bootable ISO image"
	@echo -e "  $(CYAN)test$(NC)        - Test Solix ISO with QEMU"
	@echo -e "  $(CYAN)clean$(NC)       - Clean build artifacts"
	@echo -e "  $(CYAN)distclean$(NC)   - Clean everything including downloads"
	@echo -e "  $(CYAN)info$(NC)        - Show system information"
	@echo -e "  $(CYAN)help$(NC)        - Show this help message"
	@echo
	@echo -e "$(GREEN)Build components:$(NC)"
	@echo -e "  $(CYAN)binutils$(NC)    - GNU binutils cross-compiler"
	@echo -e "  $(CYAN)gcc$(NC)         - GNU Compiler Collection"
	@echo -e "  $(CYAN)glibc$(NC)       - GNU C Library"
	@echo
	@echo -e "$(GREEN)Quick start:$(NC)"
	@echo -e "  $(YELLOW)make$(NC)           # Build everything"
	@echo -e "  $(YELLOW)make test$(NC)      # Test in QEMU"
	@echo -e "  $(YELLOW)make clean$(NC)     # Clean build files"
	@echo
	@echo -e "$(GREEN)System requirements:$(NC)"
	@echo -e "  - GCC development tools"
	@echo -e "  - GNU Make"
	@echo -e "  - GRUB tools (grub-mkrescue, xorriso)"
	@echo -e "  - QEMU (for testing)"

# Project banner
.PHONY: banner
banner:
	@echo -e "$(PURPLE)"
	@echo "███████╗ ██████╗ ██╗     ██╗██╗  ██╗"
	@echo "██╔════╝██╔═══██╗██║     ██║╚██╗██╔╝"
	@echo "███████╗██║   ██║██║     ██║ ╚███╔╝ "
	@echo "╚════██║██║   ██║██║     ██║ ██╔██╗ "
	@echo "███████║╚██████╔╝███████╗██║██╔╝ ██╗"
	@echo "╚══════╝ ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═╝"
	@echo -e "$(NC)"
	@echo -e "$(BLUE)$(PROJECT_NAME) Custom Linux - Version $(VERSION)$(NC)"
	@echo -e "$(BLUE)$(DESCRIPTION)$(NC)"
	@echo

# System information
.PHONY: info
info:
	@echo -e "$(BLUE)[INFO]$(NC) Checking build environment..."
	@echo -e "$(GREEN)System Information:$(NC)"
	@echo -e "  OS: $$(uname -s) $$(uname -r)"
	@echo -e "  Architecture: $$(uname -m)"
	@echo -e "  Shell: $$SHELL"
	@echo -e "  Make: $$(make --version | head -1)"
	@echo -e "  GCC: $$(gcc --version 2>/dev/null | head -1 || echo 'Not found')"
	@echo -e "  Available CPU cores: $$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 'Unknown')"
	@echo -e "$(GREEN)Build Configuration:$(NC)"
	@echo -e "  Project: $(PROJECT_NAME) $(VERSION)"
	@echo -e "  Target: x86_64-solix-linux-gnu"
	@echo -e "  Build directory: $$(pwd)"
	@echo

# Toolchain targets
.PHONY: toolchain binutils gcc glibc
toolchain: binutils gcc glibc
	@echo -e "$(GREEN)[SUCCESS]$(NC) Toolchain build completed"

binutils:
	@echo -e "$(BLUE)[INFO]$(NC) Building GNU binutils..."
	@cd $(TOOLCHAIN_DIR) && ./build-binutils.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) Binutils build completed"

gcc: binutils
	@echo -e "$(BLUE)[INFO]$(NC) Building GNU Compiler Collection..."
	@cd $(TOOLCHAIN_DIR) && ./build-gcc.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) GCC build completed"

glibc: gcc
	@echo -e "$(BLUE)[INFO]$(NC) Building GNU C Library..."
	@cd $(TOOLCHAIN_DIR) && ./build-glibc.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) glibc build completed"

# Kernel target
.PHONY: kernel
kernel: $(KERNEL_IMAGE)

$(KERNEL_IMAGE):
	@echo -e "$(BLUE)[INFO]$(NC) Building Linux kernel..."
	@cd $(KERNEL_DIR) && ./build-kernel.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) Kernel build completed"

# Shell target
.PHONY: shell
shell: $(SHELL_BINARY)

$(SHELL_BINARY): $(ROOTFS_DIR)/shell/shell.c
	@echo -e "$(BLUE)[INFO]$(NC) Compiling custom Solix shell..."
	@cd $(ROOTFS_DIR)/shell && gcc -o ../bin/shell shell.c -Wall -Wextra
	@echo -e "$(GREEN)[SUCCESS]$(NC) Shell compilation completed"

# Init system target
.PHONY: init
init: $(INIT_SCRIPT)
	@echo -e "$(BLUE)[INFO]$(NC) Verifying init system..."
	@test -x $(INIT_SCRIPT) && echo -e "$(GREEN)[SUCCESS]$(NC) Init system ready" || \
		(echo -e "$(RED)[ERROR]$(NC) Init script not executable" && exit 1)

# GRUB bootloader target
.PHONY: grub
grub: kernel
	@echo -e "$(BLUE)[INFO]$(NC) Setting up GRUB bootloader..."
	@cd $(GRUB_DIR) && ./build-grub.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) GRUB setup completed"

# ISO generation target
.PHONY: iso
iso: $(ISO_FILE)

$(ISO_FILE): kernel shell init
	@echo -e "$(BLUE)[INFO]$(NC) Generating bootable ISO..."
	@cd $(ISO_DIR) && ./make-iso.sh
	@echo -e "$(GREEN)[SUCCESS]$(NC) ISO generation completed"

# Test target
.PHONY: test
test: $(ISO_FILE)
	@echo -e "$(BLUE)[INFO]$(NC) Testing Solix with QEMU..."
	@if command -v qemu-system-x86_64 >/dev/null 2>&1; then \
		echo -e "$(GREEN)Starting Solix in QEMU...$(NC)"; \
		echo -e "$(YELLOW)Press Ctrl+Alt+G to release mouse$(NC)"; \
		echo -e "$(YELLOW)Press Ctrl+Alt+2 for monitor, Ctrl+Alt+1 to return$(NC)"; \
		cd $(ISO_DIR) && qemu-system-x86_64 \
			-cdrom solix-$(VERSION).iso \
			-m 512M \
			-name "Solix Linux Test" \
			-boot d \
			-enable-kvm 2>/dev/null || \
		qemu-system-x86_64 \
			-cdrom solix-$(VERSION).iso \
			-m 512M \
			-name "Solix Linux Test" \
			-boot d; \
	else \
		echo -e "$(RED)[ERROR]$(NC) QEMU not found. Install with:"; \
		echo -e "  Ubuntu/Debian: sudo apt install qemu-system-x86"; \
		echo -e "  RHEL/CentOS: sudo dnf install qemu-kvm"; \
		echo -e "  macOS: brew install qemu"; \
		exit 1; \
	fi

# Quick test without full build
.PHONY: test-quick
test-quick:
	@if [ -f "$(ISO_FILE)" ]; then \
		cd $(ISO_DIR) && ./test-solix.sh; \
	else \
		echo -e "$(RED)[ERROR]$(NC) ISO file not found. Run 'make iso' first."; \
		exit 1; \
	fi

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

# Cleaning targets
.PHONY: clean clean-toolchain clean-kernel clean-iso
clean:
	@echo -e "$(YELLOW)[CLEAN]$(NC) Removing build artifacts..."
	@rm -rf $(TOOLCHAIN_DIR)/build/ $(TOOLCHAIN_DIR)/src/ $(TOOLCHAIN_DIR)/cross-tools/
	@rm -rf $(KERNEL_DIR)/linux-*/ $(KERNEL_DIR)/build/
	@rm -rf $(ISO_DIR)/build/ $(ISO_DIR)/*.iso $(ISO_DIR)/*.sha256
	@rm -f $(SHELL_BINARY)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Build artifacts cleaned"

clean-toolchain:
	@echo -e "$(YELLOW)[CLEAN]$(NC) Cleaning toolchain..."
	@rm -rf $(TOOLCHAIN_DIR)/build/ $(TOOLCHAIN_DIR)/src/ $(TOOLCHAIN_DIR)/cross-tools/
	@echo -e "$(GREEN)[SUCCESS]$(NC) Toolchain cleaned"

clean-kernel:
	@echo -e "$(YELLOW)[CLEAN]$(NC) Cleaning kernel..."
	@rm -rf $(KERNEL_DIR)/linux-*/ $(KERNEL_DIR)/build/
	@rm -f $(KERNEL_IMAGE)
	@echo -e "$(GREEN)[SUCCESS]$(NC) Kernel cleaned"

clean-iso:
	@echo -e "$(YELLOW)[CLEAN]$(NC) Cleaning ISO..."
	@rm -rf $(ISO_DIR)/build/ $(ISO_DIR)/*.iso $(ISO_DIR)/*.sha256
	@echo -e "$(GREEN)[SUCCESS]$(NC) ISO cleaned"

.PHONY: distclean
distclean: clean
	@echo -e "$(YELLOW)[CLEAN]$(NC) Removing all downloads and builds..."
	@rm -rf $(TOOLCHAIN_DIR)/*.tar.* $(KERNEL_DIR)/*.tar.*
	@rm -rf $(GRUB_DIR)/build/
	@echo -e "$(GREEN)[SUCCESS]$(NC) Distribution clean completed"

# Status and monitoring
.PHONY: status
status:
	@echo -e "$(BLUE)╔══════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(BLUE)║                    Solix Build Status                       ║$(NC)"
	@echo -e "$(BLUE)╚══════════════════════════════════════════════════════════════╝$(NC)"
	@echo
	@echo -e "$(GREEN)Component Status:$(NC)"
	@if [ -x "$(BINUTILS_SCRIPT)" ]; then echo -e "  ✓ Binutils script ready"; else echo -e "  ✗ Binutils script missing"; fi
	@if [ -x "$(GCC_SCRIPT)" ]; then echo -e "  ✓ GCC script ready"; else echo -e "  ✗ GCC script missing"; fi
	@if [ -x "$(GLIBC_SCRIPT)" ]; then echo -e "  ✓ glibc script ready"; else echo -e "  ✗ glibc script missing"; fi
	@if [ -x "$(KERNEL_SCRIPT)" ]; then echo -e "  ✓ Kernel script ready"; else echo -e "  ✗ Kernel script missing"; fi
	@if [ -f "$(KERNEL_IMAGE)" ]; then echo -e "  ✓ Kernel built"; else echo -e "  ✗ Kernel not built"; fi
	@if [ -x "$(SHELL_BINARY)" ]; then echo -e "  ✓ Shell compiled"; else echo -e "  ✗ Shell not compiled"; fi
	@if [ -x "$(INIT_SCRIPT)" ]; then echo -e "  ✓ Init system ready"; else echo -e "  ✗ Init system missing"; fi
	@if [ -x "$(GRUB_SCRIPT)" ]; then echo -e "  ✓ GRUB script ready"; else echo -e "  ✗ GRUB script missing"; fi
	@if [ -x "$(ISO_SCRIPT)" ]; then echo -e "  ✓ ISO script ready"; else echo -e "  ✗ ISO script missing"; fi
	@if [ -f "$(ISO_FILE)" ]; then echo -e "  ✓ ISO generated"; else echo -e "  ✗ ISO not generated"; fi
	@echo

# Success message
.PHONY: success
success:
	@echo
	@echo -e "$(GREEN)╔══════════════════════════════════════════════════════════════╗$(NC)"
	@echo -e "$(GREEN)║                🎉 Solix Build Complete! 🎉                  ║$(NC)"
	@echo -e "$(GREEN)╚══════════════════════════════════════════════════════════════╝$(NC)"
	@echo
	@echo -e "$(BLUE)Your Solix Custom Linux system is ready!$(NC)"
	@echo
	@if [ -f "$(ISO_FILE)" ]; then \
		echo -e "$(GREEN)Generated files:$(NC)"; \
		echo -e "  📀 $(ISO_FILE)"; \
		echo -e "  🧪 $(ISO_DIR)/test-solix.sh"; \
		echo -e "  📄 $(ISO_DIR)/SOLIX_README.md"; \
		if [ -f "$(ISO_FILE).sha256" ]; then \
			echo -e "  🔒 $(ISO_FILE).sha256"; \
		fi; \
		echo; \
		echo -e "$(GREEN)To test your system:$(NC)"; \
		echo -e "  make test"; \
		echo; \
		echo -e "$(GREEN)Or manually:$(NC)"; \
		echo -e "  qemu-system-x86_64 -cdrom $(ISO_FILE) -m 512M"; \
		echo; \
	fi
	@echo -e "$(BLUE)Happy learning with Solix! 🐧$(NC)"

# Documentation target
.PHONY: docs
docs:
	@echo -e "$(BLUE)[INFO]$(NC) Generating project documentation..."
	@echo -e "$(GREEN)Documentation available:$(NC)"
	@echo -e "  📄 README.md - Main project documentation"
	@echo -e "  📁 Each component has its own build script with comments"
	@echo -e "  🔧 Use 'make help' for build system help"
	@if [ -f "$(ISO_DIR)/SOLIX_README.md" ]; then \
		echo -e "  📀 $(ISO_DIR)/SOLIX_README.md - ISO usage guide"; \
	fi

# Parallel build support
.PHONY: parallel
parallel:
	@echo -e "$(BLUE)[INFO]$(NC) Building with parallel jobs..."
	@$(MAKE) -j$$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) all

# Force rebuild
.PHONY: rebuild
rebuild: clean all

# Quick rebuild
.PHONY: quick
quick: dev-shell dev-iso test-quick

# Install dependencies (if supported)
.PHONY: install-deps
install-deps:
	@echo -e "$(BLUE)[INFO]$(NC) Installing build dependencies..."
	@if command -v apt >/dev/null 2>&1; then \
		sudo apt update && sudo apt install -y \
			build-essential gcc g++ make git wget \
			grub-pc-bin grub-common xorriso mtools \
			qemu-system-x86 cpio gzip; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf groupinstall -y "Development Tools" && \
		sudo dnf install -y grub2-pc grub2-tools-extra \
			xorriso qemu-kvm cpio gzip; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum groupinstall -y "Development Tools" && \
		sudo yum install -y grub2-pc grub2-tools-extra \
			xorriso qemu-kvm cpio gzip; \
	elif command -v brew >/dev/null 2>&1; then \
		brew install gcc make git wget qemu xorriso cpio; \
	else \
		echo -e "$(RED)[ERROR]$(NC) Package manager not detected"; \
		echo -e "$(YELLOW)Please install manually:$(NC)"; \
		echo -e "  - GCC development tools"; \
		echo -e "  - GNU Make"; \
		echo -e "  - Git, wget"; \
		echo -e "  - GRUB tools"; \
		echo -e "  - QEMU"; \
		exit 1; \
	fi
	@echo -e "$(GREEN)[SUCCESS]$(NC) Dependencies installed"

# Mark targets that don't create files
.PHONY: all help banner info toolchain binutils gcc glibc kernel shell init grub iso test test-quick
.PHONY: dev-shell dev-kernel dev-iso check-deps clean clean-toolchain clean-kernel clean-iso distclean
.PHONY: status success docs parallel rebuild quick install-deps 