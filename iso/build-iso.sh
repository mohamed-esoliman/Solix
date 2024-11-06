#!/usr/bin/env bash
set -euo pipefail

# Usage: build-iso.sh <BUILD_DIR_ABS> <OUT_DIR_ABS> <VERSION>

BUILD_DIR="${1:?BUILD_DIR required}"
OUT_DIR="${2:?OUT_DIR required}"
VERSION="${3:?VERSION required}"

ISO_STAGING="${BUILD_DIR}/iso-staging"
GRUB_DIR="$(cd "$(dirname "$0")" && pwd)"

rm -rf "${ISO_STAGING}"
mkdir -p "${ISO_STAGING}/boot/grub"

cp -v "${BUILD_DIR}/boot/vmlinuz" "${ISO_STAGING}/boot/"
cp -v "${BUILD_DIR}/initramfs.img" "${ISO_STAGING}/boot/"

if [[ -f "${GRUB_DIR}/grub.cfg" ]]; then
  cp -v "${GRUB_DIR}/grub.cfg" "${ISO_STAGING}/boot/grub/"
else
  echo "Missing iso/grub.cfg" >&2; exit 1
fi

ISO_NAME="solix-${VERSION}.iso"
mkdir -p "${OUT_DIR}"

if command -v grub-mkrescue >/dev/null 2>&1; then
  grub-mkrescue -o "${OUT_DIR}/${ISO_NAME}" "${ISO_STAGING}" --product-name="Solix" --product-version="${VERSION}" --volid="SOLIX" 2>/dev/null || true
fi

if [[ ! -f "${OUT_DIR}/${ISO_NAME}" ]]; then
  if command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs -R -J -o "${OUT_DIR}/${ISO_NAME}" -b boot/grub/i386-pc/eltorito.img -no-emul-boot -boot-load-size 4 -boot-info-table "${ISO_STAGING}" || true
  fi
fi

if [[ ! -f "${OUT_DIR}/${ISO_NAME}" ]]; then
  echo "Failed to create ISO. Ensure grub-mkrescue or xorriso is available." >&2
  exit 1
fi

echo "Created ISO: ${OUT_DIR}/${ISO_NAME}"

