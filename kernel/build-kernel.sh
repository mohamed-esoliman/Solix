#!/usr/bin/env bash
set -euo pipefail

# Usage: build-kernel.sh <KERNEL_VER> <BUILD_DIR_ABS>
# Downloads and builds a real Linux kernel bzImage using provided config.

KERNEL_VER="${1:-6.6.8}"
BUILD_DIR="${2:-$(pwd)/../build}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

KERNEL_TARBALL="linux-${KERNEL_VER}.tar.xz"
KERNEL_URLS=(
  "https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"
  "https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TARBALL}"
)

mkdir -p "${SCRIPT_DIR}/downloads" "${BUILD_DIR}/boot"
cd "${SCRIPT_DIR}/downloads"

if [[ ! -f "${KERNEL_TARBALL}" ]]; then
  echo "Downloading Linux ${KERNEL_VER}..."
  success=0
  for u in "${KERNEL_URLS[@]}"; do
    if curl -fSL "${u}" -o "${KERNEL_TARBALL}"; then
      success=1; break
    fi
  done
  if [[ ${success} -ne 1 ]]; then
    echo "Failed to download kernel ${KERNEL_VER}" >&2
    exit 1
  fi
fi

if [[ ! -d "linux-${KERNEL_VER}" ]]; then
  echo "Extracting kernel..."
  tar -xf "${KERNEL_TARBALL}"
fi

cd "linux-${KERNEL_VER}"

# Apply provided config
if [[ -f "${SCRIPT_DIR}/config" ]]; then
  cp "${SCRIPT_DIR}/config" .config
else
  echo "Missing kernel config at ${SCRIPT_DIR}/config" >&2
  exit 1
fi

echo "Preparing kernel config (olddefconfig)..."
make olddefconfig

JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}
echo "Building bzImage with -j${JOBS}..."
make -j"${JOBS}" bzImage

# Install artifacts
cp arch/x86/boot/bzImage "${BUILD_DIR}/boot/vmlinuz-${KERNEL_VER}-solix"
cp System.map "${BUILD_DIR}/boot/System.map-${KERNEL_VER}-solix" || true

pushd "${BUILD_DIR}/boot" >/dev/null
ln -sf "vmlinuz-${KERNEL_VER}-solix" vmlinuz
ln -sf "System.map-${KERNEL_VER}-solix" System.map || true
popd >/dev/null

echo "Kernel installed to ${BUILD_DIR}/boot/vmlinuz-${KERNEL_VER}-solix"

