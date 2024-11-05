# Solix - A Minimalist Linux From Scratch

> **Solix** = **Sol**iman + L**inux** (because why not name your OS after yourself?)

**Solix** is a minimalist Linux-based operating system built entirely from source code, following Linux From Scratch (LFS) principles. Every component is compiled and configured manually:

- **Custom Toolchain**: Binutils, GCC, and Glibc compiled from source
- **Linux Kernel**: Configured and compiled for minimal hardware support
- **Custom Init System**: Bash-based initialization
- **Custom Shell**: A minimal C-based shell with basic command support
- **GRUB Bootloader**: Configured for automatic system boot
- **Live ISO**: Bootable image for virtual machines

## Features

- Manual toolchain build with complete GCC cross-compilation environment
- Linux Kernel 6.6.x with minimal configuration
- Custom init system with lightweight bash-based startup process
- Interactive shell with `cd`, `ls`, `exit`, and program execution capabilities
- GRUB2 bootloader with automated boot configuration
- Live ISO generation for testing and demonstration
- Comprehensive boot logging and virtual filesystem support

## System Requirements

### Host System

- **OS**: Linux (Ubuntu 20.04+, Debian 11+, or equivalent)
- **Architecture**: x86_64
- **RAM**: 4GB minimum, 8GB recommended
- **Disk Space**: 10GB free space
- **Privileges**: sudo access required

### Required Packages

Ubuntu/Debian:

```bash
sudo apt update && sudo apt install -y \
    build-essential bison flex texinfo \
    gawk wget tar xz-utils cpio grub-pc-bin \
    grub-efi-amd64-bin xorriso mtools
```

RedHat/CentOS/Fedora:

```bash
sudo dnf groupinstall "Development Tools" && \
sudo dnf install bison flex texinfo gawk wget \
    tar xz cpio grub2-pc grub2-efi-x64 \
    xorriso mtools
```

## Quick Start

```bash
# Clone the project
git clone <repository-url> solix
cd solix

# Build the complete system
make all

# Test in QEMU
make test

# Clean build artifacts
make clean
```

## Build Process

### Automated Build

```bash
make all
```

### Manual Build Steps

1. **Build Toolchain**

```bash
cd toolchain
./build-binutils.sh
./build-gcc.sh
./build-glibc.sh
```

2. **Compile Kernel**

```bash
cd kernel
./build-kernel.sh
```

3. **Build Custom Shell**

```bash
cd rootfs/shell
gcc -o ../bin/shell shell.c
```

4. **Configure Bootloader**

```bash
cd grub
./build-grub.sh
```

5. **Generate ISO**

```bash
cd iso
./make-iso.sh
```

## Architecture

### Boot Sequence

1. **GRUB Bootloader** loads and starts the Linux kernel
2. **Kernel Initialization** performs hardware detection and driver loading
3. **Init System** executes custom `/etc/init.d/rcS` script
4. **Virtual Filesystems** mounting of `/proc`, `/sys`, `/dev`
5. **Shell Launch** provides user interaction

### Key Components

**Custom Init System** (`/etc/init.d/rcS`)

- Mounts virtual filesystems
- Sets up basic system environment
- Configures network interfaces
- Launches the custom shell
- Logs activities to `/var/log/boot.log`

**Custom Shell** (`shell.c`)

- Interactive command prompt
- Built-in commands: `cd`, `exit`, `help`
- External program execution
- Command parsing and error handling

## Usage

### Testing the System

**QEMU**:

```bash
qemu-system-x86_64 -cdrom iso/solix.iso -m 512M
```

**VirtualBox**:

- Create new VM
- Mount `iso/solix.iso` as CD/DVD
- Boot from CD/DVD

### Available Commands

```bash
solix> ls           # List directory contents
solix> cd /home     # Change directory
solix> echo hello   # Echo text
solix> help         # Show available commands
solix> exit         # Shutdown system
```

## Important Notes

- This project is designed for educational purposes and system demonstration
- The system has minimal security features and hardware support
- Optimized for virtualization environments
- Changes are not persistent across reboots (live system)
- Recommended for use in virtual machines only

## Contributing

Contributions are welcome. Please fork the repository, create a feature branch, and open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## References

- [Linux From Scratch](http://www.linuxfromscratch.org/)
- [The Linux Kernel Documentation](https://www.kernel.org/doc/)
- [GNU Toolchain Documentation](https://gcc.gnu.org/onlinedocs/)
- [GRUB Manual](https://www.gnu.org/software/grub/manual/)
