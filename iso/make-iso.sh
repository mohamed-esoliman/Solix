#!/bin/bash
#
# Solix ISO Generation Script
# Part of the Solix custom Linux build
#
# Copyright (c) 2024 Mohamed Soliman
# Licensed under the MIT License
#
# This script creates the final bootable ISO image for Solix
# by combining all components: kernel, rootfs, init system, shell, and bootloader.
#

set -e  # Exit on any error

# Configuration
SOLIX_VERSION="1.0"
ISO_NAME="solix-${SOLIX_VERSION}.iso"
BUILD_DIR="build"
ROOTFS_DIR="../rootfs"
KERNEL_DIR="../kernel"
GRUB_DIR="../grub"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print Solix banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    Solix ISO Generator                      ║"
    echo "║                     Version $SOLIX_VERSION                          ║"
    echo "║                                                              ║"
    echo "║  Creating bootable ISO for Solix Custom Linux              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for ISO generation..."
    
    local missing_tools=()
    local required_tools=(xorriso genisoimage mkisofs grub-mkrescue)
    
    # Check for at least one ISO creation tool
    local iso_tool_found=false
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            iso_tool_found=true
            break
        fi
    done
    
    if [ "$iso_tool_found" = false ]; then
        log_error "No ISO creation tool found!"
        log_error "Please install one of: ${required_tools[*]}"
        exit 1
    fi
    
    # Check for essential components
    if [ ! -f "$ROOTFS_DIR/boot/vmlinuz" ]; then
        log_error "Kernel not found. Please run: kernel/build-kernel.sh"
        exit 1
    fi
    
    if [ ! -x "$ROOTFS_DIR/bin/shell" ]; then
        log_error "Custom shell not found. Please compile it first."
        exit 1
    fi
    
    if [ ! -x "$ROOTFS_DIR/etc/init.d/rcS" ]; then
        log_error "Init script not found or not executable."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Setup build environment
setup_build_environment() {
    log_info "Setting up build environment..."
    
    # Create build directories
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"/{iso,rootfs,boot/grub}
    
    # Create temporary root filesystem
    mkdir -p "$BUILD_DIR/rootfs"/{bin,sbin,etc,lib,lib64,usr/{bin,sbin,lib},var/{log,run,tmp},proc,sys,dev,tmp,home,root,boot}
    
    log_success "Build environment created"
}

# Copy and prepare root filesystem
prepare_rootfs() {
    log_info "Preparing root filesystem..."
    
    # Copy essential directories and files
    cp -r "$ROOTFS_DIR/bin" "$BUILD_DIR/rootfs/" 2>/dev/null || mkdir -p "$BUILD_DIR/rootfs/bin"
    cp -r "$ROOTFS_DIR/sbin" "$BUILD_DIR/rootfs/" 2>/dev/null || mkdir -p "$BUILD_DIR/rootfs/sbin"
    cp -r "$ROOTFS_DIR/etc" "$BUILD_DIR/rootfs/" 2>/dev/null || mkdir -p "$BUILD_DIR/rootfs/etc"
    cp -r "$ROOTFS_DIR/home" "$BUILD_DIR/rootfs/" 2>/dev/null || mkdir -p "$BUILD_DIR/rootfs/home"
    cp -r "$ROOTFS_DIR/root" "$BUILD_DIR/rootfs/" 2>/dev/null || mkdir -p "$BUILD_DIR/rootfs/root"
    cp -r "$ROOTFS_DIR/var" "$BUILD_DIR/rootfs/" 2>/dev/null || mkdir -p "$BUILD_DIR/rootfs/var"
    
    # Ensure custom shell is in place
    if [ -x "$ROOTFS_DIR/bin/shell" ]; then
        cp "$ROOTFS_DIR/bin/shell" "$BUILD_DIR/rootfs/bin/"
        chmod +x "$BUILD_DIR/rootfs/bin/shell"
        log_success "Custom shell copied"
    fi
    
    # Ensure init script is in place
    if [ -f "$ROOTFS_DIR/etc/init.d/rcS" ]; then
        mkdir -p "$BUILD_DIR/rootfs/etc/init.d"
        cp "$ROOTFS_DIR/etc/init.d/rcS" "$BUILD_DIR/rootfs/etc/init.d/"
        chmod +x "$BUILD_DIR/rootfs/etc/init.d/rcS"
        log_success "Init script copied"
    fi
    
    # Create essential device nodes
    create_device_nodes
    
    # Create basic filesystem structure
    create_basic_filesystem
    
    log_success "Root filesystem prepared"
}

# Create essential device nodes
create_device_nodes() {
    log_info "Creating essential device nodes..."
    
    local dev_dir="$BUILD_DIR/rootfs/dev"
    
    # Create basic device nodes (will be replaced by devtmpfs at boot)
    mknod "$dev_dir/null" c 1 3 2>/dev/null || true
    mknod "$dev_dir/zero" c 1 5 2>/dev/null || true
    mknod "$dev_dir/random" c 1 8 2>/dev/null || true
    mknod "$dev_dir/urandom" c 1 9 2>/dev/null || true
    mknod "$dev_dir/console" c 5 1 2>/dev/null || true
    mknod "$dev_dir/tty" c 5 0 2>/dev/null || true
    
    # Create some tty devices
    for i in {0..6}; do
        mknod "$dev_dir/tty$i" c 4 $i 2>/dev/null || true
    done
    
    log_success "Device nodes created"
}

# Create basic filesystem structure and files
create_basic_filesystem() {
    log_info "Creating basic filesystem structure..."
    
    local rootfs="$BUILD_DIR/rootfs"
    
    # Create /etc/fstab
    cat > "$rootfs/etc/fstab" << 'EOF'
# Solix filesystem table
proc        /proc       proc    defaults        0   0
sysfs       /sys        sysfs   defaults        0   0
devtmpfs    /dev        devtmpfs defaults       0   0
tmpfs       /tmp        tmpfs   size=64M        0   0
tmpfs       /var/tmp    tmpfs   size=32M        0   0
EOF
    
    # Create /etc/passwd
    cat > "$rootfs/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/shell
EOF
    
    # Create /etc/group
    cat > "$rootfs/etc/group" << 'EOF'
root:x:0:
EOF
    
    # Create /etc/shadow (basic)
    cat > "$rootfs/etc/shadow" << 'EOF'
root::19000:0:99999:7:::
EOF
    
    # Create /etc/hosts
    cat > "$rootfs/etc/hosts" << 'EOF'
127.0.0.1   localhost solix
::1         localhost solix
EOF
    
    # Create /etc/hostname
    echo "solix" > "$rootfs/etc/hostname"
    
    # Create /etc/resolv.conf
    cat > "$rootfs/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    
    # Create /etc/motd
    cat > "$rootfs/etc/motd" << 'EOF'
Welcome to Solix!

This is a minimal Linux system built from scratch.
Type 'help' to see available commands.

Solix = Soliman + Linux
Built with ♥ and way too much coffee.
EOF
    
    # Create basic init symlink
    ln -sf /etc/init.d/rcS "$rootfs/init" 2>/dev/null || true
    
    # Set permissions
    chmod 600 "$rootfs/etc/shadow"
    chmod 644 "$rootfs/etc/passwd" "$rootfs/etc/group" "$rootfs/etc/hosts"
    chmod 755 "$rootfs/etc"
    
    log_success "Basic filesystem structure created"
}

# Create initramfs
create_initramfs() {
    log_info "Creating initramfs..."
    
    local initramfs_dir="$BUILD_DIR/initramfs"
    local rootfs_dir="$BUILD_DIR/rootfs"
    
    # Create initramfs directory structure
    rm -rf "$initramfs_dir"
    mkdir -p "$initramfs_dir"
    
    # Copy the entire rootfs to initramfs
    cp -r "$rootfs_dir"/* "$initramfs_dir/"
    
    # Create initramfs archive
    cd "$initramfs_dir"
    
    log_info "Creating compressed initramfs archive..."
    find . | cpio -o -H newc | gzip -9 > "../boot/initramfs.img"
    
    cd - > /dev/null
    
    # Verify initramfs creation
    if [ -f "$BUILD_DIR/boot/initramfs.img" ]; then
        local size=$(stat -c%s "$BUILD_DIR/boot/initramfs.img" 2>/dev/null || stat -f%z "$BUILD_DIR/boot/initramfs.img" 2>/dev/null)
        log_success "Initramfs created: ${size} bytes"
    else
        log_error "Failed to create initramfs"
        exit 1
    fi
}

# Prepare boot files
prepare_boot_files() {
    log_info "Preparing boot files..."
    
    # Copy kernel
    if [ -f "$ROOTFS_DIR/boot/vmlinuz" ]; then
        cp "$ROOTFS_DIR/boot/vmlinuz" "$BUILD_DIR/boot/"
        log_success "Kernel copied"
    else
        log_error "Kernel not found!"
        exit 1
    fi
    
    # Copy System.map if available
    if [ -f "$ROOTFS_DIR/boot/System.map" ]; then
        cp "$ROOTFS_DIR/boot/System.map" "$BUILD_DIR/boot/"
        log_success "System.map copied"
    fi
    
    log_success "Boot files prepared"
}

# Setup GRUB configuration
setup_grub() {
    log_info "Setting up GRUB bootloader..."
    
    # Create GRUB directory structure
    mkdir -p "$BUILD_DIR/boot/grub"
    
    # Copy GRUB configuration
    if [ -f "$GRUB_DIR/grub.cfg" ]; then
        cp "$GRUB_DIR/grub.cfg" "$BUILD_DIR/boot/grub/"
        log_success "GRUB configuration copied"
    else
        log_warning "GRUB config not found, creating basic one..."
        create_basic_grub_config
    fi
    
    # Create GRUB environment
    cat > "$BUILD_DIR/boot/grub/grubenv" << 'EOF'
# GRUB Environment Block
saved_entry=0
EOF
    
    log_success "GRUB setup completed"
}

# Create basic GRUB configuration
create_basic_grub_config() {
    cat > "$BUILD_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=3
set default=0

menuentry "Solix Linux" {
    echo "Loading Solix kernel..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/init console=tty0 quiet
    echo "Loading initramfs..."
    initrd /boot/initramfs.img
    echo "Starting Solix..."
}

menuentry "Solix Linux (Verbose)" {
    echo "Loading Solix kernel with verbose output..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/init console=tty0 debug loglevel=7
    initrd /boot/initramfs.img
}
EOF
}

# Create ISO image
create_iso() {
    log_info "Creating ISO image..."
    
    cd "$BUILD_DIR"
    
    # Try different ISO creation methods
    if command -v grub-mkrescue &> /dev/null; then
        log_info "Using grub-mkrescue..."
        grub-mkrescue -o "../$ISO_NAME" . \
            --product-name="Solix Linux" \
            --product-version="$SOLIX_VERSION" \
            --volid="SOLIX" 2>/dev/null || iso_fallback
    else
        iso_fallback
    fi
    
    cd - > /dev/null
    
    log_success "ISO creation completed"
}

# Fallback ISO creation methods
iso_fallback() {
    log_warning "Trying alternative ISO creation methods..."
    
    # Create isolinux configuration for fallback
    mkdir -p isolinux
    cat > isolinux/isolinux.cfg << 'EOF'
DEFAULT solix
LABEL solix
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.img root=/dev/ram0 rw init=/init
EOF
    
    if command -v xorriso &> /dev/null; then
        log_info "Using xorriso..."
        xorriso -as mkisofs \
            -volid "SOLIX" \
            -joliet -joliet-long \
            -rational-rock \
            -output "../$ISO_NAME" . 2>/dev/null
    elif command -v genisoimage &> /dev/null; then
        log_info "Using genisoimage..."
        genisoimage -r -J -V "SOLIX" -o "../$ISO_NAME" .
    elif command -v mkisofs &> /dev/null; then
        log_info "Using mkisofs..."
        mkisofs -r -J -V "SOLIX" -o "../$ISO_NAME" .
    else
        log_error "No ISO creation tool available!"
        exit 1
    fi
}

# Verify ISO
verify_iso() {
    log_info "Verifying ISO..."
    
    if [ -f "$ISO_NAME" ]; then
        local size=$(stat -c%s "$ISO_NAME" 2>/dev/null || stat -f%z "$ISO_NAME" 2>/dev/null)
        log_success "ISO created: $ISO_NAME (${size} bytes)"
        
        # Basic verification
        if command -v file &> /dev/null; then
            local file_info=$(file "$ISO_NAME")
            log_info "File info: $file_info"
        fi
        
        # Create checksum
        if command -v sha256sum &> /dev/null; then
            sha256sum "$ISO_NAME" > "${ISO_NAME}.sha256"
            log_success "SHA256 checksum created"
        elif command -v shasum &> /dev/null; then
            shasum -a 256 "$ISO_NAME" > "${ISO_NAME}.sha256"
            log_success "SHA256 checksum created"
        fi
        
    else
        log_error "ISO creation failed!"
        exit 1
    fi
}

# Create documentation and test scripts
create_documentation() {
    log_info "Creating documentation and test scripts..."
    
    # Create test script
    cat > "test-solix.sh" << 'EOF'
#!/bin/bash
# Solix ISO Test Script

echo "Testing Solix ISO..."
echo "==================="
echo

if command -v qemu-system-x86_64 &> /dev/null; then
    echo "Starting Solix in QEMU..."
    echo "Press Ctrl+Alt+G to release mouse"
    echo "Press Ctrl+Alt+2 for monitor, Ctrl+Alt+1 to return"
    echo
    qemu-system-x86_64 \
        -cdrom solix-1.0.iso \
        -m 512M \
        -name "Solix Linux" \
        -boot d \
        -enable-kvm 2>/dev/null || \
    qemu-system-x86_64 \
        -cdrom solix-1.0.iso \
        -m 512M \
        -name "Solix Linux" \
        -boot d
else
    echo "QEMU not found. Install with:"
    echo "  Ubuntu/Debian: sudo apt install qemu-system-x86"
    echo "  RHEL/CentOS: sudo dnf install qemu-kvm"
    echo
    echo "Alternative test methods:"
    echo "1. VirtualBox: Create VM and mount solix-1.0.iso"
    echo "2. VMware: Create VM and mount solix-1.0.iso"  
    echo "3. Physical hardware: Burn to USB/CD and boot"
fi
EOF
    
    chmod +x test-solix.sh
    
    # Create README
    cat > "SOLIX_README.md" << 'EOF'
# Solix Custom Linux System

## Overview
Solix is a minimal Linux distribution built entirely from scratch. It demonstrates the core components and build process of a modern Linux system.

## Contents
- **solix-1.0.iso**: Bootable ISO image
- **test-solix.sh**: Quick test script for QEMU
- **solix-1.0.iso.sha256**: Checksum verification

## Quick Start

### Testing in QEMU
```bash
./test-solix.sh
```

### Manual QEMU
```bash
qemu-system-x86_64 -cdrom solix-1.0.iso -m 512M
```

### VirtualBox
1. Create new Linux VM
2. Mount solix-1.0.iso as CD/DVD
3. Boot from CD/DVD

### VMware
1. Create new Linux VM
2. Mount solix-1.0.iso as CD/DVD
3. Boot from CD/DVD

## System Features
- Custom kernel (Linux 6.6.8)
- Custom shell with built-in commands
- GRUB2 bootloader
- Minimal root filesystem
- Custom init system

## Available Commands
Once booted, try these commands in the Solix shell:
- `help` - Show available commands
- `ls` - List directory contents
- `cd` - Change directory
- `pwd` - Show current directory
- `cat` - Display file contents
- `echo` - Display text
- `clear` - Clear screen
- `history` - Show command history
- `uptime` - Show system uptime
- `exit` - Shutdown system

## System Requirements
- x86_64 processor
- 512MB RAM minimum
- VGA-compatible display
- CD/DVD drive or USB boot capability

## What This Shows
This system demonstrates:
- Linux kernel compilation and configuration
- Custom toolchain creation (binutils, GCC, glibc)
- Init system development
- Shell programming in C
- Bootloader configuration
- ISO image creation

## License
Copyright (c) 2024 Mohamed Soliman - MIT License. Components retain their original licenses.

## About
Solix = Soliman + Linux
Built as a demonstration of Linux From Scratch principles.
EOF
    
    log_success "Documentation created"
}

# Display build summary
display_summary() {
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    Build Summary                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    log_info "Solix ISO Generation Completed Successfully!"
    echo
    log_info "Generated Files:"
    log_info "  📀 $ISO_NAME - Bootable ISO image"
    log_info "  🧪 test-solix.sh - QEMU test script"
    log_info "  📄 SOLIX_README.md - Documentation"
    if [ -f "${ISO_NAME}.sha256" ]; then
        log_info "  🔒 ${ISO_NAME}.sha256 - Checksum"
    fi
    echo
    log_info "To test your Solix system:"
    log_info "  ./test-solix.sh"
    echo
    log_info "Or manually:"
    log_info "  qemu-system-x86_64 -cdrom $ISO_NAME -m 512M"
    echo
    log_success "🎉 Solix Custom Linux is ready!"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$BUILD_DIR"
    log_success "Cleanup completed"
}

# Main execution
main() {
    print_banner
    
    log_info "Starting Solix ISO generation process..."
    log_info "Version: $SOLIX_VERSION"
    log_info "Output: $ISO_NAME"
    echo
    
    check_prerequisites
    setup_build_environment
    prepare_rootfs
    create_initramfs
    prepare_boot_files
    setup_grub
    create_iso
    verify_iso
    create_documentation
    cleanup
    display_summary
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@" 