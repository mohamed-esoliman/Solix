# Solix - A Minimalist Linux From Scratch

> **Solix** = **Sol**iman + L**inux** (because why not name your OS after yourself?)


This repository builds a small, bootable Linux system using:

- **Linux Kernel 6.6.8** (real bzImage)
- **BusyBox (static)** as minimal userland and `/bin/sh`
- **Custom Init** script at `rootfs/etc/init.d/rcS` (supports switch_root to persistent ext4)
- **Custom C Shell** compiled statically and included in initramfs (now with history, redirs, pipes, which, export/unset)
- **GRUB ISO** for CD/VM boot, plus QEMU run with kernel+initramfs

## Features

- Real upstream Linux kernel 6.6.8 (bzImage)
- Minimal kernel config enabling initramfs, devtmpfs (auto-mount), serial console
- Static BusyBox userland providing `/bin/sh` and core applets
- Custom init (`rootfs/etc/init.d/rcS`) as PID1 handoff via `/init` with optional `switch_root` to ext4
- BusyBox init with `/etc/inittab` spawning getty on `ttyS0` and `tty1` when persistent root is in use
- Optional DHCP on `eth0` via `udhcpc` (`/etc/network.up`)
- Custom static C shell included in initramfs and installed into persistent root
- GRUB ISO build for VM boot, plus direct QEMU boot (kernel+initramfs)
- Simple, reproducible build via Docker
- Boot logs to `/var/log/boot.log` in initramfs

## System Requirements

- Recommended: Docker (Linux/macOS host), x86_64 CPU, 8GB RAM, ~10GB free disk
- Optional (host build without Docker): gcc/make, kernel build deps, `grub-mkrescue`, `xorriso`, `qemu`

## Quick Start (Docker recommended)

```bash
# Clone
git clone <repository-url> solix
cd solix

# Build container
docker build -t solix-build .

# Build everything inside container (bind mount your repo)
docker run --rm -it -v "$PWD":/workspace -w /workspace solix-build bash -lc "make all"

# Run with QEMU from the container or host (initramfs only)
docker run --rm -it --device /dev/kvm -v "$PWD":/workspace -w /workspace solix-build bash -lc "make run" || \
qemu-system-x86_64 -kernel build/boot/vmlinuz -initrd build/initramfs.img -m 512M -nographic -serial mon:stdio -append "console=ttyS0 quiet"

# Persistent rootfs image and run
make rootfsimg && make run-persistent
```

## Build Process

### Make targets

```bash
make all        # kernel + busybox + custom shell + initramfs + ISO -> out/solix-1.0.iso
make kernel     # download and build Linux 6.6.8 bzImage
make busybox    # build static BusyBox, install to busybox/_install
make shell      # compile rootfs/shell/shell.c statically into build/rootfs/bin/shell
make initramfs  # build build/initramfs.img with /init, rcS, BusyBox, and custom shell
make iso        # produce out/solix-1.0.iso with GRUB
make run        # boot with QEMU using kernel+initramfs
make rootfsimg  # builds build/rootfs.img ext4 and populates it
make run-persistent  # boot kernel+initramfs with rootfs.img attached as virtio disk
make utils      # build static utilities
make test       # smoke boot up to 20s; grep for key boot log lines
```

### Boot Flow

```
GRUB/QEMU -> kernel -> initramfs /init -> rcS -> (optional) switch_root to ext4 -> BusyBox init/getty -> login or shell
```

### Shell capabilities

- Prompt: username@hostname:cwd$
- History: in-memory + persistent at ~/.solix_history
- Built-ins: cd, pwd, echo, help, exit, history, which, export, unset
- External exec via PATH lookup
- Redirections: >, >>, <
- Pipe: single pipeline cmd1 | cmd2
- Chaining: cmd1 && cmd2, cmd1 || cmd2, cmd1 ; cmd2
- Exit status: $? expansion

### Try these

- uptime_lite, ps_lite, meminfo_lite
- ifconfig/udhcpc (if present)

Note: root login is passwordless for demo only. Do not use in production.

- First kernel build can take 20–60 minutes depending on CPU cores; subsequent runs are fast.

## Architecture

### Key Components

**Custom Init System** (`/etc/init.d/rcS`)

- Mounts `/proc`, `/sys`, `/dev`
- Sets hostname and environment
- Optional simple network bring-up
- Launches the custom shell

**Custom Shell** (`rootfs/shell/shell.c`)

- Built-ins: `cd`, `pwd`, `help`, `exit`, `clear`, `echo`, `ls`, `cat`, `history`, `uptime`
- Static binary included in initramfs

## Usage

### Testing the System

**QEMU ISO mode**:

```bash
qemu-system-x86_64 -cdrom out/solix-1.0.iso -m 512M
```

**VirtualBox**:

- Create new VM (Linux x86_64)
- Mount `out/solix-1.0.iso` as CD/DVD
- Boot from CD/DVD

## Contributing

Contributions are welcome. Please fork the repository, create a feature branch, and open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## References

- `https://www.kernel.org/`
- `https://busybox.net/`
- `https://www.gnu.org/software/grub/manual/`
