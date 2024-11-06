#!/usr/bin/env bash
set -euo pipefail

# Build static BusyBox and install into busybox/_install

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${SCRIPT_DIR}/_install"
BB_VER="1.36.1"
TARBALL="busybox-${BB_VER}.tar.bz2"
URLS=(
  "https://busybox.net/downloads/${TARBALL}"
  "https://mirror.tochlab.net/busybox/${TARBALL}"
)

mkdir -p "${SCRIPT_DIR}/downloads"
cd "${SCRIPT_DIR}/downloads"

if [[ ! -f "${TARBALL}" ]]; then
  echo "Downloading BusyBox ${BB_VER}..."
  ok=0
  for u in "${URLS[@]}"; do
    if curl -fSL "$u" -o "${TARBALL}"; then ok=1; break; fi
  done
  if [[ $ok -ne 1 ]]; then
    echo "Failed to download BusyBox" >&2; exit 1
  fi
fi

if [[ ! -d "busybox-${BB_VER}" ]]; then
  tar -xf "${TARBALL}"
fi

cd "busybox-${BB_VER}"

# Use provided defconfig
if [[ -f "${SCRIPT_DIR}/busybox.config" ]]; then
  cp "${SCRIPT_DIR}/busybox.config" .config
else
  echo "Missing busybox.config at ${SCRIPT_DIR}/busybox.config" >&2
  exit 1
fi

JOBS=${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)}
CC_BIN="$(command -v musl-gcc || true)"
if [[ -n "${CC_BIN}" ]]; then
  export CC="${CC_BIN}"
fi

make olddefconfig
make -j"${JOBS}"
make CONFIG_PREFIX="${INSTALL_DIR}" install

echo "BusyBox installed to ${INSTALL_DIR}"

