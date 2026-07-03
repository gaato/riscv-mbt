#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$repo_root/_build/alpine-rootfs"
version="${ALPINE_VERSION:-3.24.1}"
arch="${ALPINE_ARCH:-riscv64}"
base_url="${ALPINE_BASE_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/$arch}"
rootfs_name="alpine-minirootfs-$version-$arch.tar.gz"
rootfs_url="$base_url/$rootfs_name"
sha_url="$rootfs_url.sha256"
initrd_addr="${ALPINE_INITRD_ADDR:-0x84000000}"
initrd_name="alpine-initramfs-$arch.cpio.gz"

mkdir -p "$build_dir" "$repo_root/_build"

if [[ ! -f "$build_dir/$rootfs_name" ]]; then
  curl -L -o "$build_dir/$rootfs_name" "$rootfs_url"
fi

curl -L -o "$build_dir/$rootfs_name.sha256" "$sha_url"
(
  cd "$build_dir"
  sha256sum -c "$rootfs_name.sha256"
)

root_dir="$(mktemp -d "$repo_root/_build/alpine-rootfs.XXXXXX")"
trap 'rm -rf "$root_dir"' EXIT

tar -xzf "$build_dir/$rootfs_name" -C "$root_dir"
mkdir -p "$root_dir"/proc "$root_dir"/sys "$root_dir"/dev "$root_dir"/tmp
cat > "$root_dir/init" <<'EOF'
#!/bin/sh
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
echo "riscv-mbt Alpine initramfs ready"
exec /bin/sh
EOF
chmod +x "$root_dir/init"

(
  cd "$root_dir"
  find . -print0 | cpio --null -o --format=newc | gzip -9 > "$repo_root/_build/$initrd_name"
)

initrd_size="$(wc -c < "$repo_root/_build/$initrd_name")"
initrd_start="$((initrd_addr))"
initrd_end="$((initrd_start + initrd_size))"

python3 "$repo_root/tools/build_minimal_dtb.py" \
  --initrd-start "$(printf '0x%x' "$initrd_start")" \
  --initrd-end "$(printf '0x%x' "$initrd_end")" \
  > "$repo_root/_build/minimal-alpine.dtb"

printf 'alpine rootfs: %s\n' "$build_dir/$rootfs_name"
printf 'initrd: %s (%s bytes) @ 0x%x..0x%x\n' \
  "$repo_root/_build/$initrd_name" "$initrd_size" "$initrd_start" "$initrd_end"
printf 'dtb: %s\n' "$repo_root/_build/minimal-alpine.dtb"
