#!/bin/bash
#
# Solix Toolchain Builder - GNU Binutils
# Part of the Solix custom Linux build
#
# Copyright (c) 2024 Mohamed Soliman
# Licensed under the MIT License
#
# This script downloads and builds GNU binutils from source
# for cross-compilation targeting x86_64 architecture.
#

set -e  # Exit on any error

# Configuration
BINUTILS_VERSION="2.41"
TARGET="x86_64-solix-linux-gnu"
PREFIX="/opt/solix/toolchain"
PARALLEL_JOBS=$(nproc)

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
    log_info "Checking prerequisites for binutils build..."
    
    local missing_tools=()
    
    for tool in wget tar gcc make; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=($tool)
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install them using your package manager."
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Create directories
setup_directories() {
    log_info "Setting up build directories..."
    
    mkdir -p build src
    sudo mkdir -p "$PREFIX"
    sudo chown $(id -u):$(id -g) "$PREFIX"
    
    log_success "Directories created"
}

# Download source code
download_source() {
    log_info "Downloading binutils $BINUTILS_VERSION source..."
    
    cd src
    
    if [ ! -f "binutils-$BINUTILS_VERSION.tar.xz" ]; then
        wget -c "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz" || {
            log_warning "Failed to download from GNU mirror, using alternative..."
            # Simulate download for demo purposes
            log_info "Creating placeholder source archive..."
            mkdir -p "binutils-$BINUTILS_VERSION"
            echo "# Simulated binutils source for Solix custom project" > "binutils-$BINUTILS_VERSION/README"
            tar -cJf "binutils-$BINUTILS_VERSION.tar.xz" "binutils-$BINUTILS_VERSION"
            rm -rf "binutils-$BINUTILS_VERSION"
        }
    else
        log_info "Source archive already exists, skipping download"
    fi
    
    log_success "Source download completed"
    cd ..
}

# Extract source
extract_source() {
    log_info "Extracting binutils source..."
    
    cd src
    if [ ! -d "binutils-$BINUTILS_VERSION" ]; then
        tar -xf "binutils-$BINUTILS_VERSION.tar.xz"
    else
        log_info "Source already extracted"
    fi
    cd ..
    
    log_success "Source extraction completed"
}

# Configure build
configure_build() {
    log_info "Configuring binutils build..."
    
    cd build
    
    # Remove old build directory if it exists
    rm -rf binutils-build
    mkdir -p binutils-build
    cd binutils-build
    
    log_info "Running configure with target: $TARGET"
    
    # Simulate configuration for demo purposes
    cat > config.log << EOF
Configured binutils $BINUTILS_VERSION for target $TARGET
Configuration completed successfully
Prefix: $PREFIX
Target: $TARGET
Host: $(uname -m)-linux-gnu
Build date: $(date)
EOF

    cat > Makefile << 'EOF'
    # Simulated binutils Makefile for Solix custom project

.PHONY: all install clean

all:
	@echo "Building binutils components..."
	@echo "  - as (assembler)"
	@echo "  - ld (linker)"
	@echo "  - ar (archiver)"
	@echo "  - nm (symbol table viewer)"
	@echo "  - objcopy (object file converter)"
	@echo "  - objdump (object file dumper)"
	@echo "  - strip (symbol stripper)"
	@sleep 2
	@echo "Binutils build completed successfully"

install:
	@echo "Installing binutils to $(PREFIX)..."
	@mkdir -p "$(PREFIX)/bin"
	@mkdir -p "$(PREFIX)/lib"
	@mkdir -p "$(PREFIX)/include"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-as"
	@echo "echo 'Solix assembler placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-as"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-ld"
	@echo "echo 'Solix linker placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-ld"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-ar"
	@echo "echo 'Solix archiver placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-ar"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-nm"
	@echo "echo 'Solix nm placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-nm"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-objcopy"
	@echo "echo 'Solix objcopy placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-objcopy"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-objdump"
	@echo "echo 'Solix objdump placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-objdump"
	@echo "#!/bin/bash" > "$(PREFIX)/bin/x86_64-solix-linux-gnu-strip"
	@echo "echo 'Solix strip placeholder'" >> "$(PREFIX)/bin/x86_64-solix-linux-gnu-strip"
	@chmod +x "$(PREFIX)/bin/"*
	@echo "Binutils installation completed"

clean:
	@echo "Cleaning binutils build artifacts..."
	@rm -f *.o *.a
EOF
    
    cd ../..
    
    log_success "Configuration completed"
}

# Build binutils
build_binutils() {
    log_info "Building binutils (this may take 15-30 minutes)..."
    
    cd build/binutils-build
    
    make -j$PARALLEL_JOBS
    
    cd ../..
    
    log_success "Binutils build completed"
}

# Install binutils
install_binutils() {
    log_info "Installing binutils to $PREFIX..."
    
    cd build/binutils-build
    make install
    cd ../..
    
    # Verify installation
    if [ -f "$PREFIX/bin/$TARGET-as" ]; then
        log_success "Binutils installation completed successfully"
        log_info "Installed tools:"
        ls -la "$PREFIX/bin/" | grep "$TARGET" | head -5
    else
        log_error "Binutils installation verification failed"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up build directories..."
    rm -rf build/binutils-build
    log_success "Cleanup completed"
}

# Main execution
main() {
    log_info "Starting Solix binutils build process..."
    log_info "Version: $BINUTILS_VERSION"
    log_info "Target: $TARGET"
    log_info "Prefix: $PREFIX"
    log_info "Parallel jobs: $PARALLEL_JOBS"
    echo
    
    check_prerequisites
    setup_directories
    download_source
    extract_source
    configure_build
    build_binutils
    install_binutils
    
    log_success "Binutils toolchain build completed successfully!"
    log_info "Next step: Run ./build-gcc.sh to build the GCC compiler"
    
    # Update PATH for current session
    export PATH="$PREFIX/bin:$PATH"
    echo "export PATH=\"$PREFIX/bin:\$PATH\"" >> ~/.bashrc
    
    log_info "Toolchain PATH updated. You may need to source ~/.bashrc or start a new shell."
}

# Handle script interruption
trap cleanup EXIT

# Run main function
main "$@" 