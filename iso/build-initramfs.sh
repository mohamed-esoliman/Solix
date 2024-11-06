#!/usr/bin/env bash
set -euo pipefail

# Usage: build-initramfs.sh <BUILD_DIR_ABS> <BUSYBOX_INSTALL_ABS> <ROOTFS_SRC_ABS>

BUILD_DIR="${1:?BUILD_DIR required}"
BB_INSTALL="${2:?BUSYBOX_INSTALL path required}"
ROOTFS_SRC="${3:?ROOTFS_SRC path required}"

WORKDIR="${BUILD_DIR}/initramfs-root"
INITRD="${BUILD_DIR}/initramfs.img"

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"/{bin,sbin,etc,proc,sys,dev,tmp,usr/bin,root,home}

# Copy BusyBox and create sh symlink
if [[ ! -x "${BB_INSTALL}/bin/busybox" ]]; then
  echo "BusyBox not found at ${BB_INSTALL}/bin/busybox" >&2
  exit 1
fi
rsync -a "${BB_INSTALL}/" "${WORKDIR}/"
ln -sf /bin/busybox "${WORKDIR}/bin/sh"

# Create minimal device nodes expected early (best-effort; may fail in containers)
mknod -m 622 "${WORKDIR}/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "${WORKDIR}/dev/null" c 1 3 2>/dev/null || true

# Init script: use user's rcS as PID1 via /init
install -d "${WORKDIR}/etc/init.d"
install -m 0755 "${ROOTFS_SRC}/etc/init.d/rcS" "${WORKDIR}/etc/init.d/rcS"
cat > "${WORKDIR}/init" << 'EOF'
#!/bin/sh
echo "[initramfs] Solix early init"
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
exec /etc/init.d/rcS
EOF
chmod +x "${WORKDIR}/init"

# Include custom static shell
if [[ -x "${BUILD_DIR}/rootfs/bin/shell" ]]; then
  install -D -m 0755 "${BUILD_DIR}/rootfs/bin/shell" "${WORKDIR}/bin/shell"
fi

# Include minimal udhcpc script for DHCP
if [[ -f "${ROOTFS_SRC}/etc/udhcpc.script" ]]; then
  install -D -m 0755 "${ROOTFS_SRC}/etc/udhcpc.script" "${WORKDIR}/etc/udhcpc.script"
fi

# Optional network bring-up helper
if [[ -f "${ROOTFS_SRC}/etc/network.up" ]]; then
  install -D -m 0755 "${ROOTFS_SRC}/etc/network.up" "${WORKDIR}/etc/network.up"
fi

# Create archive
cd "${WORKDIR}"
find . -print0 | cpio --null -ov --format=newc | gzip -9 > "${INITRD}"
echo "Created initramfs: ${INITRD}"

