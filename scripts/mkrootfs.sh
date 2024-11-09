#!/usr/bin/env bash
set -euo pipefail

# Solix: Create/populate persistent ext4 root filesystem image
# - Idempotent: safe to re-run
# - Tries to mount to populate; if mount not possible, image will be populated on first boot by initramfs

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
BUSYBOX_INSTALL="${ROOT_DIR}/busybox/_install"
ROOTFS_SRC="${ROOT_DIR}/rootfs"

IMG_PATH="${BUILD_DIR}/rootfs.img"
IMG_SIZE_MB="128"
MNT_DIR="${BUILD_DIR}/mnt-rootfs"

mkdir -p "${BUILD_DIR}"

create_img() {
  if [[ -f "${IMG_PATH}" ]]; then
    echo "[mkrootfs] Using existing image: ${IMG_PATH}"
    return
  fi
  echo "[mkrootfs] Creating ${IMG_SIZE_MB}MB ext4 image at ${IMG_PATH}"
  dd if=/dev/zero of="${IMG_PATH}" bs=1M count="${IMG_SIZE_MB}" status=none
  mkfs.ext4 -F -L SOLIX_ROOT "${IMG_PATH}" >/dev/null
}

try_mount_guest() {
  if command -v guestmount >/dev/null 2>&1; then
    echo "[mkrootfs] Mounting with guestmount..."
    mkdir -p "${MNT_DIR}"
    guestmount -a "${IMG_PATH}" -m /dev/sda1 --pid-file "${BUILD_DIR}/guestmount.pid" "${MNT_DIR}" || return 1
    echo guest >"${MNT_DIR}/.solix_mount_method"
    return 0
  fi
  return 1
}

try_mount_loop() {
  if [[ $EUID -ne 0 ]]; then
    echo "[mkrootfs] Not root; will try sudo for loop mount"
  fi
  mkdir -p "${MNT_DIR}"
  # Setup loop device
  local loopdev
  loopdev=$(sudo losetup -P -f --show "${IMG_PATH}") || return 1
  trap 'sudo losetup -d "${loopdev}" >/dev/null 2>&1 || true' EXIT
  echo "[mkrootfs] Loop device: ${loopdev}"
  sudo mount -t ext4 "${loopdev}" "${MNT_DIR}" || sudo mount -t ext4 "${loopdev}p1" "${MNT_DIR}" || return 1
  echo loop >"${MNT_DIR}/.solix_mount_method"
  return 0
}

populate_tree() {
  echo "[mkrootfs] Populating rootfs tree..."
  install -d -m 0755 "${MNT_DIR}"/{bin,sbin,etc,proc,sys,dev,run,tmp,usr/bin,usr/sbin,root,home,var/log}

  # Install BusyBox and applets into target root (symlinks)
  if [[ -x "${BUSYBOX_INSTALL}/bin/busybox" ]]; then
    install -D -m 0755 "${BUSYBOX_INSTALL}/bin/busybox" "${MNT_DIR}/bin/busybox"
    chroot "${MNT_DIR}" /bin/busybox --install -s /
    ln -sf /bin/busybox "${MNT_DIR}/bin/sh"
  else
    echo "[mkrootfs] WARNING: BusyBox not built yet; initramfs will populate on first boot"
  fi

  # Install custom shell and utilities from build
  if [[ -x "${BUILD_DIR}/rootfs/bin/shell" ]]; then
    install -D -m 0755 "${BUILD_DIR}/rootfs/bin/shell" "${MNT_DIR}/bin/shell"
  fi
  for u in uptime_lite ps_lite meminfo_lite; do
    if [[ -x "${BUILD_DIR}/rootfs/bin/${u}" ]]; then
      install -D -m 0755 "${BUILD_DIR}/rootfs/bin/${u}" "${MNT_DIR}/bin/${u}"
    fi
  done

  # Base configs: inittab, rcS, passwd, shadow, network.up, hostname, hosts
  install -d -m 0755 "${MNT_DIR}/etc/init.d"
  if [[ -f "${ROOTFS_SRC}/etc/init.d/rcS" ]]; then
    install -m 0755 "${ROOTFS_SRC}/etc/init.d/rcS" "${MNT_DIR}/etc/init.d/rcS"
  fi
  if [[ -f "${ROOTFS_SRC}/etc/inittab" ]]; then
    install -m 0644 "${ROOTFS_SRC}/etc/inittab" "${MNT_DIR}/etc/inittab"
  else
    cat >"${MNT_DIR}/etc/inittab" <<'EOF'
::sysinit:/etc/init.d/rcS
ttyS0::respawn:/sbin/getty -L ttyS0 115200 vt100
tty1::respawn:/sbin/getty tty1 9600
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
EOF
  fi
  if [[ -f "${ROOTFS_SRC}/etc/network.up" ]]; then
    install -m 0755 "${ROOTFS_SRC}/etc/network.up" "${MNT_DIR}/etc/network.up"
  fi

  echo solix >"${MNT_DIR}/etc/hostname"
  cat >"${MNT_DIR}/etc/hosts" <<'EOF'
127.0.0.1   localhost solix
::1         localhost solix
EOF

  # Root user (no password, demo only)
  echo 'root::0:0:root:/root:/bin/sh' >"${MNT_DIR}/etc/passwd"
  echo 'root::19700:0:99999:7:::' >"${MNT_DIR}/etc/shadow"
  chmod 0600 "${MNT_DIR}/etc/shadow"

  # Secure ttys for root
  printf "ttyS0\ntty1\nconsole\n" >"${MNT_DIR}/etc/securetty"

  echo "[mkrootfs] Population complete"
}

unmount_any() {
  if mountpoint -q "${MNT_DIR}"; then
    echo "[mkrootfs] Unmounting ${MNT_DIR}"
    if [[ -f "${MNT_DIR}/.solix_mount_method" ]] && grep -q guest "${MNT_DIR}/.solix_mount_method" 2>/dev/null; then
      guestunmount "${MNT_DIR}" || true
    else
      sudo umount "${MNT_DIR}" || true
    fi
  fi
}

main() {
  create_img

  if try_mount_guest || try_mount_loop; then
    trap unmount_any EXIT
    populate_tree
  else
    echo "[mkrootfs] NOTE: Could not mount image; it will be auto-populated on first boot by initramfs."
  fi
}

main "$@"


