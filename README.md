# 🐧 Solix - A Minimalist Linux From Scratch

> **Solix** = **Sol**iman + L**inux**  
> _Because why not name a Linux distro after yourself? At least it's not "SolimanOS" 😄_

![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-handcrafted-blue)

**Solix** is a minimalist Linux-based operating system built entirely from source code, following Linux From Scratch (LFS) principles. This is a custom, handcrafted Linux build that shows what's possible when you roll your own OS from the ground up.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Quick Start](#quick-start)
- [Build Process](#build-process)
- [Project Structure](#project-structure)
- [How It Works](#how-it-works)
- [Usage](#usage)
- [Warnings](#warnings)
- [Contributing](#contributing)

## 🎯 Overview

Solix is a from-scratch Linux build that creates a bootable system without any package managers or shortcuts. Every single component is compiled and configured by hand:

- **Custom Toolchain**: Binutils, GCC, and Glibc compiled from source
- **Linux Kernel**: Configured and compiled for minimal hardware support
- **Custom Init System**: Bash-based initialization replacing systemd
- **Custom Shell**: A minimal C-based shell with basic command support
- **GRUB Bootloader**: Configured for automatic system boot
- **Live ISO**: Bootable image for virtual machines or real hardware

## ✨ Features

- 🔧 **Manual Toolchain Build**: Complete GCC cross-compilation environment
- 🐧 **Linux Kernel 6.6.x**: Latest stable kernel with minimal configuration
- 🚀 **Custom Init System**: Lightweight bash-based startup process
- 💻 **Custom Shell**: Interactive shell with `cd`, `ls`, `exit`, and program execution
- 🥾 **GRUB2 Bootloader**: Automated boot configuration
- 💿 **Live ISO Generation**: Bootable image creation
- 📊 **Boot Logging**: Comprehensive startup event logging
- 🔄 **Virtual Filesystem Support**: Automatic mounting of `/proc`, `/sys`, `/dev`

## 🖥️ System Requirements

### Host System

- **OS**: Linux (Ubuntu 20.04+, Debian 11+, or equivalent)
- **Architecture**: x86_64
- **RAM**: 4GB minimum, 8GB recommended
- **Disk Space**: 10GB free space
- **Privileges**: sudo access required

### Required Packages

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y \
    build-essential bison flex texinfo \
    gawk wget tar xz-utils cpio grub-pc-bin \
    grub-efi-amd64-bin xorriso mtools

# RedHat/CentOS/Fedora
sudo dnf groupinstall "Development Tools" && \
sudo dnf install bison flex texinfo gawk wget \
    tar xz cpio grub2-pc grub2-efi-x64 \
    xorriso mtools
```

### Virtualization (Recommended)

- **QEMU**: For testing the generated ISO
- **VirtualBox**: Alternative virtualization platform
- **VMware**: Also supported

## 🚀 Quick Start

```bash
# Clone or create the project
git clone <repository-url> solix
cd solix

# Build the complete system (takes 2-4 hours)
make all

# Test in QEMU
make test

# Clean build artifacts
make clean
```

## 🔨 Build Process

### Manual Step-by-Step Build

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

3. **Setup Root Filesystem**

```bash
cd scripts
./setup-chroot.sh
./mount-virtual-fs.sh
```

4. **Build Custom Shell**

```bash
cd rootfs/shell
gcc -o ../bin/shell shell.c
```

5. **Configure Bootloader**

```bash
cd grub
./build-grub.sh
```

6. **Generate ISO**

```bash
cd iso
./make-iso.sh
```

### Automated Build

```bash
make all
```

## 📁 Project Structure

```
solix/
├── README.md                    # This file
├── Makefile                     # Build orchestration
├── toolchain/                   # Cross-compilation tools
│   ├── build-binutils.sh       # GNU binutils build script
│   ├── build-gcc.sh            # GCC compiler build script
│   └── build-glibc.sh          # GNU C Library build script
├── kernel/                      # Linux kernel configuration
│   ├── config                  # Kernel configuration file
│   ├── build-kernel.sh         # Kernel compilation script
│   └── linux-6.x/              # Downloaded kernel source (auto-generated)
├── rootfs/                      # Root filesystem structure
│   ├── etc/init.d/rcS          # Custom init script
│   ├── bin/                    # System binaries
│   ├── dev/, proc/, sys/, tmp/  # Virtual filesystem mount points
│   ├── home/                   # User home directories
│   ├── var/log/                # System logs
│   └── shell/                  # Custom shell source
│       └── shell.c             # Shell implementation
├── grub/                       # Bootloader configuration
│   ├── grub.cfg                # GRUB configuration
│   └── build-grub.sh           # GRUB setup script
├── iso/                        # ISO generation
│   ├── make-iso.sh             # ISO creation script
│   └── solix.iso               # Generated bootable image
└── scripts/                    # Utility scripts
    ├── setup-chroot.sh         # Chroot environment setup
    └── mount-virtual-fs.sh     # Virtual filesystem mounting
```

## ⚙️ How It Works

### Boot Sequence

1. **GRUB Bootloader**: Loads and starts the Linux kernel
2. **Kernel Initialization**: Hardware detection and driver loading
3. **Init System**: Custom `/etc/init.d/rcS` script execution
4. **Virtual Filesystems**: Mounting of `/proc`, `/sys`, `/dev`
5. **Shell Launch**: Custom shell provides user interaction

### Key Components

**Custom Init System (`/etc/init.d/rcS`)**

- Mounts virtual filesystems
- Sets up basic system environment
- Configures network interfaces (if available)
- Launches the custom shell
- Logs all activities to `/var/log/boot.log`

**Custom Shell (`shell.c`)**

- Interactive command prompt: `solix> `
- Built-in commands: `cd`, `exit`, `help`
- External program execution
- Basic error handling and command parsing

**Kernel Configuration**

- Minimal hardware support for common virtualization platforms
- Essential filesystems: ext4, proc, sysfs, devtmpfs
- Basic networking support
- No unnecessary drivers or modules

## 🎮 Usage

### Booting Solix

1. **In QEMU**:

```bash
qemu-system-x86_64 -cdrom iso/solix.iso -m 512M
```

2. **In VirtualBox**:

   - Create new VM
   - Mount `iso/solix.iso` as CD/DVD
   - Boot from CD/DVD

3. **On Real Hardware** (⚠️ **Not recommended for production**):
   - Burn ISO to USB/CD
   - Boot from USB/CD

### Available Commands

Once booted, you'll see the `solix> ` prompt. Available commands:

```bash
solix> ls           # List directory contents
solix> cd /home     # Change directory
solix> echo hello   # Echo text
solix> help         # Show available commands
solix> exit         # Shutdown system
```

## ⚠️ Warnings

- **Custom Build**: Solix is designed for learning and portfolio demonstration
- **No Package Manager**: All software must be compiled manually
- **Minimal Security**: No user authentication or access controls
- **Limited Hardware Support**: Optimized for virtualization environments
- **No Persistence**: Changes are lost on reboot (live system)
- **Use in VM Only**: Not recommended for production or daily use

## 🔍 Development Notes

### Customization

**Adding New Commands to Shell**:

1. Edit `rootfs/shell/shell.c`
2. Add command parsing logic
3. Recompile: `gcc -o rootfs/bin/shell rootfs/shell/shell.c`

**Modifying Init Process**:

1. Edit `rootfs/etc/init.d/rcS`
2. Add initialization steps as needed
3. Rebuild ISO

**Kernel Configuration**:

1. Edit `kernel/config`
2. Run `kernel/build-kernel.sh`
3. Rebuild ISO

### Troubleshooting

**Build Fails**:

- Ensure all dependencies are installed
- Check available disk space
- Verify sudo privileges

**ISO Doesn't Boot**:

- Verify GRUB configuration in `grub/grub.cfg`
- Check kernel path in bootloader
- Ensure ISO was created successfully

**Shell Doesn't Work**:

- Check shell compilation: `file rootfs/bin/shell`
- Verify init script permissions: `chmod +x rootfs/etc/init.d/rcS`

## 🤝 Contributing

This is a custom project, but contributions are welcome!

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📜 License

Copyright (c) 2024 Mohamed Soliman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

**Note**: This project incorporates components from various open-source projects
(Linux kernel, GNU toolchain, GRUB) which retain their original licenses.

## 📚 Learning Resources

- [Linux From Scratch](http://www.linuxfromscratch.org/)
- [The Linux Kernel Documentation](https://www.kernel.org/doc/)
- [GNU Toolchain Documentation](https://gcc.gnu.org/onlinedocs/)
- [GRUB Manual](https://www.gnu.org/software/grub/manual/)

## 🎯 Project Goals Achieved

- ✅ Manual toolchain compilation
- ✅ Linux kernel configuration and compilation
- ✅ Custom init system implementation
- ✅ Custom shell development in C
- ✅ GRUB bootloader configuration
- ✅ Bootable ISO generation
- ✅ Custom Linux build demonstration
- ✅ Portfolio-worthy systems programming showcase

---

**Solix** - _Proving that sometimes the best way to understand something is to build it yourself._
