FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    bc bison flex libssl-dev \
    libelf-dev libncurses5-dev libncursesw5-dev \
    dwarves \
    git curl ca-certificates wget xz-utils cpio rsync gzip \
    musl-tools \
    qemu-system-x86 \
    grub-pc-bin grub-efi-amd64-bin grub-common xorriso mtools \
    squashfs-tools \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user to avoid root-owned build outputs on bind mounts
RUN useradd -m -u 1000 builder && mkdir -p /workspace && chown -R builder:builder /workspace
USER builder
WORKDIR /workspace

# Default command prints help
CMD ["bash", "-lc", "echo 'Solix builder container ready. Run: make all && make run'"]


