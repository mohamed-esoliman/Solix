#!/bin/bash
#
# Solix GRUB Bootloader Builder
# Part of the Solix custom Linux build
#
# Copyright (c) 2024 Mohamed Soliman
# Licensed under the MIT License
#
# This script sets up GRUB2 bootloader for the Solix ISO
# and creates the necessary boot configuration.
#

set -e  # Exit on any error

# Configuration
GRUB_VERSION="2.12"
ISO_BUILD_DIR="../iso/build"
ROOTFS_DIR="../rootfs"
GRUB_CFG="../grub/grub.cfg"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for GRUB build..."
    
    local missing_tools=()
    
    # Check for required tools
    for tool in grub-mkrescue grub-install xorriso; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_warning "Missing GRUB tools: ${missing_tools[*]}"
        log_info "Attempting to install GRUB tools..."
        
        # Try to install GRUB tools
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y grub-pc-bin grub-common xorriso mtools
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y grub2-pc grub2-tools-extra xorriso
        elif command -v yum &> /dev/null; then
            sudo yum install -y grub2-pc grub2-tools-extra xorriso
        else
            log_error "Package manager not found. Please install GRUB tools manually:"
            log_error "  Ubuntu/Debian: sudo apt install grub-pc-bin grub-common xorriso mtools"
            log_error "  RHEL/CentOS: sudo dnf install grub2-pc grub2-tools-extra xorriso"
            exit 1
        fi
    fi
    
    # Check for kernel and initramfs
    if [ ! -f "$ROOTFS_DIR/boot/vmlinuz" ]; then
        log_error "Kernel not found at $ROOTFS_DIR/boot/vmlinuz"
        log_error "Please run the kernel build script first"
        exit 1
    fi
    
    if [ ! -f "$ROOTFS_DIR/boot/initramfs.img" ]; then
        log_warning "Initramfs not found at $ROOTFS_DIR/boot/initramfs.img"
        log_warning "System may not boot properly without initramfs"
    fi
    
    log_success "Prerequisites check completed"
}

# Create ISO build directory structure
setup_iso_structure() {
    log_info "Setting up ISO directory structure..."
    
    # Create ISO build directories
    mkdir -p "$ISO_BUILD_DIR"/{boot/grub,efi/boot}
    
    # Create boot directory structure
    mkdir -p "$ISO_BUILD_DIR/boot/grub/"{fonts,locale,themes}
    
    log_success "ISO structure created"
}

# Copy kernel and initramfs
copy_boot_files() {
    log_info "Copying boot files..."
    
    # Copy kernel
    if [ -f "$ROOTFS_DIR/boot/vmlinuz" ]; then
        cp "$ROOTFS_DIR/boot/vmlinuz" "$ISO_BUILD_DIR/boot/"
        log_success "Kernel copied"
    else
        log_error "Kernel file not found!"
        exit 1
    fi
    
    # Copy initramfs if available
    if [ -f "$ROOTFS_DIR/boot/initramfs.img" ]; then
        cp "$ROOTFS_DIR/boot/initramfs.img" "$ISO_BUILD_DIR/boot/"
        log_success "Initramfs copied"
    else
        log_warning "Initramfs not found, creating minimal one..."
        create_minimal_initramfs
    fi
    
    # Copy System.map if available
    if [ -f "$ROOTFS_DIR/boot/System.map" ]; then
        cp "$ROOTFS_DIR/boot/System.map" "$ISO_BUILD_DIR/boot/"
        log_success "System.map copied"
    fi
    
    log_success "Boot files copied"
}

# Create minimal initramfs if needed
create_minimal_initramfs() {
    log_info "Creating minimal initramfs..."
    
    local initramfs_dir="/tmp/solix-initramfs"
    
    # Create temporary directory structure
    rm -rf "$initramfs_dir"
    mkdir -p "$initramfs_dir"/{bin,sbin,etc,proc,sys,dev,lib,lib64,usr/{bin,sbin},var,tmp,root,home}
    
    cd "$initramfs_dir"
    
    # Create basic init script
    cat > init << 'EOF'
#!/bin/sh
echo "Solix minimal initramfs"
echo "Mounting essential filesystems..."

mount -t proc proc /proc
mount -t sysfs sysfs /sys  
mount -t devtmpfs devtmpfs /dev

echo "Solix initramfs ready"
echo "Starting system..."

# Try to mount real root and switch to it
if [ -b /dev/sda1 ]; then
    mkdir -p /newroot
    mount /dev/sda1 /newroot
    exec switch_root /newroot /sbin/init
fi

# Fallback to emergency shell
exec /bin/sh
EOF
    
    chmod +x init
    
    # Create basic device nodes
    mknod dev/console c 5 1 2>/dev/null || true
    mknod dev/null c 1 3 2>/dev/null || true
    mknod dev/zero c 1 5 2>/dev/null || true
    
    # Create initramfs archive
    find . | cpio -o -H newc | gzip > "$ISO_BUILD_DIR/boot/initramfs.img"
    
    cd - > /dev/null
    rm -rf "$initramfs_dir"
    
    log_success "Minimal initramfs created"
}

# Setup GRUB configuration
setup_grub_config() {
    log_info "Setting up GRUB configuration..."
    
    # Copy main GRUB configuration
    if [ -f "$GRUB_CFG" ]; then
        cp "$GRUB_CFG" "$ISO_BUILD_DIR/boot/grub/"
        log_success "GRUB configuration copied"
    else
        log_warning "GRUB config not found, creating basic one..."
        create_basic_grub_config
    fi
    
    # Create GRUB environment file
    cat > "$ISO_BUILD_DIR/boot/grub/grubenv" << 'EOF'
# GRUB Environment Block
saved_entry=0
EOF
    
    log_success "GRUB configuration setup completed"
}

# Create basic GRUB configuration if needed
create_basic_grub_config() {
    log_info "Creating basic GRUB configuration..."
    
    cat > "$ISO_BUILD_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=3
set default=0

menuentry "Solix Linux" {
    echo "Loading Solix kernel..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/etc/init.d/rcS console=tty0
    echo "Loading initramfs..."
    initrd /boot/initramfs.img
    echo "Starting Solix..."
}

menuentry "Solix Linux (Recovery)" {
    echo "Loading Solix in recovery mode..."
    linux /boot/vmlinuz root=/dev/ram0 rw init=/bin/sh console=tty0
    initrd /boot/initramfs.img
}
EOF
    
    log_success "Basic GRUB configuration created"
}

# Install GRUB fonts and themes
install_grub_assets() {
    log_info "Installing GRUB assets..."
    
    # Try to copy GRUB fonts from system
    local grub_font_dirs=(
        "/usr/share/grub/fonts"
        "/boot/grub/fonts"
        "/usr/lib/grub/fonts"
    )
    
    for font_dir in "${grub_font_dirs[@]}"; do
        if [ -d "$font_dir" ]; then
            cp -r "$font_dir"/* "$ISO_BUILD_DIR/boot/grub/fonts/" 2>/dev/null || true
            log_success "GRUB fonts copied from $font_dir"
            break
        fi
    done
    
    # Create basic font if none found
    if [ ! -f "$ISO_BUILD_DIR/boot/grub/fonts/unicode.pf2" ]; then
        log_warning "Unicode font not found, GRUB will use basic text mode"
        # Create empty font file to prevent errors
        touch "$ISO_BUILD_DIR/boot/grub/fonts/unicode.pf2"
    fi
    
    # Copy GRUB modules if available
    local grub_module_dirs=(
        "/usr/lib/grub/i386-pc"
        "/boot/grub/i386-pc"
        "/usr/share/grub/i386-pc"
    )
    
    for module_dir in "${grub_module_dirs[@]}"; do
        if [ -d "$module_dir" ]; then
            mkdir -p "$ISO_BUILD_DIR/boot/grub/i386-pc"
            cp "$module_dir"/*.mod "$ISO_BUILD_DIR/boot/grub/i386-pc/" 2>/dev/null || true
            cp "$module_dir"/*.lst "$ISO_BUILD_DIR/boot/grub/i386-pc/" 2>/dev/null || true
            log_success "GRUB modules copied from $module_dir"
            break
        fi
    done
    
    log_success "GRUB assets installation completed"
}

# Create bootable image structure
create_boot_structure() {
    log_info "Creating bootable image structure..."
    
    # Create El Torito boot catalog structure for CD/DVD booting
    mkdir -p "$ISO_BUILD_DIR/isolinux"
    
    # Create basic isolinux configuration as fallback
    cat > "$ISO_BUILD_DIR/isolinux/isolinux.cfg" << 'EOF'
DEFAULT solix
LABEL solix
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.img root=/dev/ram0 rw init=/etc/init.d/rcS
EOF
    
    # Create autorun for Windows compatibility
    cat > "$ISO_BUILD_DIR/autorun.inf" << 'EOF'
[autorun]
open=README.txt
icon=solix.ico
label=Solix Linux
EOF
    
    # Create README for the ISO
    cat > "$ISO_BUILD_DIR/README.txt" << 'EOF'
Solix Custom Linux System
==========================

This is a bootable ISO image of Solix, a custom Linux distribution
built entirely from scratch following Linux From Scratch principles.

To boot this system:
1. Burn this ISO to a CD/DVD or create a bootable USB drive
2. Boot from the CD/DVD or USB drive
3. Select "Solix Linux" from the GRUB menu

For virtualization:
- QEMU: qemu-system-x86_64 -cdrom solix.iso -m 512M
- VirtualBox: Create new VM and mount this ISO
- VMware: Create new VM and mount this ISO

System Requirements:
- x86_64 processor
- 512MB RAM minimum
- VGA-compatible display

For more information, visit the project documentation.
EOF
    
    log_success "Boot structure created"
}

# Build GRUB bootloader
build_grub() {
    log_info "Building GRUB bootloader..."
    
    cd "$ISO_BUILD_DIR"
    
    # Create GRUB rescue image
    if command -v grub-mkrescue &> /dev/null; then
        log_info "Using grub-mkrescue to create bootable image..."
        
        # Build with GRUB
        grub-mkrescue -o ../solix.iso . \
            --product-name="Solix Linux" \
            --product-version="1.0" \
            --volid="SOLIX" 2>/dev/null || {
            log_warning "grub-mkrescue failed, trying alternative method..."
            create_alternative_bootable_iso
        }
    else
        log_warning "grub-mkrescue not available, creating alternative bootable ISO..."
        create_alternative_bootable_iso
    fi
    
    cd - > /dev/null
    
    log_success "GRUB bootloader build completed"
}

# Create alternative bootable ISO
create_alternative_bootable_iso() {
    log_info "Creating alternative bootable ISO with xorriso..."
    
    if command -v xorriso &> /dev/null; then
        xorriso -as mkisofs \
            -volid "SOLIX" \
            -joliet -joliet-long \
            -rational-rock \
            -isohybrid-mbr /usr/lib/syslinux/mbr/isohdpfx.bin \
            -eltorito-boot isolinux/isolinux.bin \
            -eltorito-catalog isolinux/boot.cat \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -output ../solix.iso . 2>/dev/null || {
            log_warning "xorriso with isolinux failed, creating basic ISO..."
            create_basic_iso
        }
    else
        create_basic_iso
    fi
}

# Create basic ISO as last resort
create_basic_iso() {
    log_info "Creating basic ISO image..."
    
    if command -v genisoimage &> /dev/null; then
        genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -V "SOLIX" -o ../solix.iso .
    elif command -v mkisofs &> /dev/null; then
        mkisofs -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -V "SOLIX" -o ../solix.iso .
    else
        log_error "No ISO creation tool found!"
        log_error "Please install: genisoimage, mkisofs, or xorriso"
        exit 1
    fi
}

# Verify ISO creation
verify_iso() {
    log_info "Verifying ISO creation..."
    
    local iso_file="../solix.iso"
    
    if [ -f "$iso_file" ]; then
        local iso_size=$(stat -c%s "$iso_file" 2>/dev/null || stat -f%z "$iso_file" 2>/dev/null || echo "unknown")
        log_success "ISO created successfully: solix.iso (${iso_size} bytes)"
        
        # Basic ISO verification
        if command -v file &> /dev/null; then
            local file_info=$(file "$iso_file")
            log_info "ISO info: $file_info"
        fi
        
        # Test ISO mountability (if possible)
        if command -v isoinfo &> /dev/null; then
            log_info "ISO contents verification:"
            isoinfo -l -i "$iso_file" | head -20 || true
        fi
        
    else
        log_error "ISO creation failed!"
        exit 1
    fi
}

# Create test script
create_test_script() {
    log_info "Creating test scripts..."
    
    cat > "../test-solix.sh" << 'EOF'
#!/bin/bash
# Solix ISO Test Script

echo "Testing Solix ISO with QEMU..."
echo "Requirements: qemu-system-x86_64"
echo "Press Ctrl+Alt+G to release mouse from QEMU"
echo "Press Ctrl+Alt+2 for QEMU monitor, Ctrl+Alt+1 to return"
echo ""

if command -v qemu-system-x86_64 &> /dev/null; then
    echo "Starting Solix in QEMU..."
    qemu-system-x86_64 \
        -cdrom solix.iso \
        -m 512M \
        -enable-kvm \
        -name "Solix Linux Test" \
        -boot d
else
    echo "QEMU not found. Install with:"
    echo "  Ubuntu/Debian: sudo apt install qemu-system-x86"
    echo "  RHEL/CentOS: sudo dnf install qemu-kvm"
    echo ""
    echo "Alternative test methods:"
    echo "1. Burn solix.iso to CD/DVD and boot"
    echo "2. Create bootable USB with dd or similar tool"
    echo "3. Use VirtualBox or VMware with solix.iso"
fi
EOF
    
    chmod +x "../test-solix.sh"
    
    log_success "Test script created: test-solix.sh"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    # Remove any temporary files if needed
    rm -rf /tmp/solix-initramfs
    log_success "Cleanup completed"
}

# Main execution
main() {
    log_info "Starting Solix GRUB bootloader build..."
    echo
    
    check_prerequisites
    setup_iso_structure
    copy_boot_files
    setup_grub_config
    install_grub_assets
    create_boot_structure
    build_grub
    verify_iso
    create_test_script
    
    log_success "Solix GRUB bootloader build completed successfully!"
    log_info "Generated files:"
    log_info "  - solix.iso (bootable ISO image)"
    log_info "  - test-solix.sh (QEMU test script)"
    echo
    log_info "To test the ISO:"
    log_info "  ./test-solix.sh"
    log_info "Or manually:"
    log_info "  qemu-system-x86_64 -cdrom solix.iso -m 512M"
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@" 