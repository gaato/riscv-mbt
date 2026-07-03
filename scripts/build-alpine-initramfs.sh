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
uboot_name="alpine-uboot-$version-$arch.tar.gz"
uboot_url="$base_url/$uboot_name"
uboot_sha_url="$uboot_url.sha256"
initrd_addr="${ALPINE_INITRD_ADDR:-0x84000000}"
initrd_format="${ALPINE_INITRD_FORMAT:-cpio}"
case "$initrd_format" in
  cpio|gzip) ;;
  *)
    echo "unsupported ALPINE_INITRD_FORMAT: $initrd_format" >&2
    exit 1
    ;;
esac
initrd_cpio_name="alpine-initramfs-$arch.cpio"
initrd_gzip_name="alpine-initramfs-$arch.cpio.gz"
if [[ "$initrd_format" == "gzip" ]]; then
  initrd_name="$initrd_gzip_name"
else
  initrd_name="$initrd_cpio_name"
fi

mkdir -p "$build_dir" "$repo_root/_build"

if [[ ! -f "$build_dir/$rootfs_name" ]]; then
  curl -L -o "$build_dir/$rootfs_name" "$rootfs_url"
fi

curl -L -o "$build_dir/$rootfs_name.sha256" "$sha_url"
(
  cd "$build_dir"
  sha256sum -c "$rootfs_name.sha256"
)

if [[ ! -f "$build_dir/$uboot_name" ]]; then
  curl -L -o "$build_dir/$uboot_name" "$uboot_url"
fi

curl -L -o "$build_dir/$uboot_name.sha256" "$uboot_sha_url"
(
  cd "$build_dir"
  sha256sum -c "$uboot_name.sha256"
)

tar -xOzf "$build_dir/$uboot_name" ./boot/vmlinuz-lts |
  gzip -dc > "$repo_root/_build/linux-kernel-riscv64"

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
  find . -print0 | cpio --null -o --format=newc > "$repo_root/_build/$initrd_cpio_name"
  gzip -9c "$repo_root/_build/$initrd_cpio_name" > "$repo_root/_build/$initrd_gzip_name"
)

initrd_size="$(wc -c < "$repo_root/_build/$initrd_name")"
initrd_start="$((initrd_addr))"
initrd_end="$((initrd_start + initrd_size))"

python3 "$repo_root/tools/build_minimal_dtb.py" \
  --initrd-start "$(printf '0x%x' "$initrd_start")" \
  --initrd-end "$(printf '0x%x' "$initrd_end")" \
  > "$repo_root/_build/minimal-alpine.dtb"

printf 'alpine rootfs: %s\n' "$build_dir/$rootfs_name"
printf 'kernel image: %s (%s bytes)\n' \
  "$repo_root/_build/linux-kernel-riscv64" \
  "$(wc -c < "$repo_root/_build/linux-kernel-riscv64")"
printf 'initrd: %s (%s bytes, format=%s) @ 0x%x..0x%x\n' \
  "$repo_root/_build/$initrd_name" "$initrd_size" "$initrd_format" \
  "$initrd_start" "$initrd_end"
printf 'initrd gzip: %s (%s bytes)\n' \
  "$repo_root/_build/$initrd_gzip_name" \
  "$(wc -c < "$repo_root/_build/$initrd_gzip_name")"
printf 'dtb: %s\n' "$repo_root/_build/minimal-alpine.dtb"
