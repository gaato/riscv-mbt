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
initrd_profile="${ALPINE_INITRD_PROFILE:-tiny}"
init_style="${ALPINE_INIT_STYLE:-static}"
timebase_frequency="${ALPINE_TIMEBASE_FREQUENCY:-100000000}"
case "$initrd_format" in
  cpio|gzip) ;;
  *)
    echo "unsupported ALPINE_INITRD_FORMAT: $initrd_format" >&2
    exit 1
    ;;
esac
case "$initrd_profile" in
  full|tiny) ;;
  *)
    echo "unsupported ALPINE_INITRD_PROFILE: $initrd_profile" >&2
    exit 1
    ;;
esac
case "$init_style" in
  shell|static) ;;
  *)
    echo "unsupported ALPINE_INIT_STYLE: $init_style" >&2
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

if [[ "$initrd_profile" == "tiny" ]]; then
  mkdir -p "$root_dir"/bin "$root_dir"/lib
  tar -xzf "$build_dir/$rootfs_name" -C "$root_dir" \
    ./bin/busybox \
    ./bin/sh \
    ./lib/ld-musl-riscv64.so.1 \
    ./lib/libc.musl-riscv64.so.1
else
  tar -xzf "$build_dir/$rootfs_name" -C "$root_dir"
fi
mkdir -p "$root_dir"/proc "$root_dir"/sys "$root_dir"/dev "$root_dir"/tmp
if [[ "$init_style" == "static" ]]; then
  riscv64-elf-as -march=rv64imac -mabi=lp64 \
    -o "$repo_root/_build/alpine-init.o" \
    "$repo_root/tools/alpine-init.S"
  riscv64-elf-ld -nostdlib -static \
    -o "$root_dir/init" \
    "$repo_root/_build/alpine-init.o"
else
  cat > "$root_dir/init" <<'EOF'
#!/bin/sh
mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sysfs /sys 2>/dev/null || true
mount -t devtmpfs devtmpfs /dev 2>/dev/null || true
echo "riscv-mbt Alpine initramfs ready"
exec /bin/sh
EOF
fi
chmod +x "$root_dir/init"

fakeroot sh -c '
  set -e
  root_dir="$1"
  cpio_path="$2"
  gzip_path="$3"
  mkdir -p "$root_dir/dev"
  rm -f "$root_dir/dev/console" "$root_dir/dev/kmsg" "$root_dir/dev/null" "$root_dir/dev/zero" "$root_dir/dev/tty"
  mknod -m 600 "$root_dir/dev/console" c 5 1
  mknod -m 600 "$root_dir/dev/kmsg" c 1 11
  mknod -m 666 "$root_dir/dev/null" c 1 3
  mknod -m 666 "$root_dir/dev/zero" c 1 5
  mknod -m 666 "$root_dir/dev/tty" c 5 0
  chown -hR 0:0 "$root_dir"
  (
    cd "$root_dir"
    find . -print0 | cpio --null -o --format=newc > "$cpio_path"
  )
  gzip -9c "$cpio_path" > "$gzip_path"
' sh "$root_dir" "$repo_root/_build/$initrd_cpio_name" "$repo_root/_build/$initrd_gzip_name"

initrd_size="$(wc -c < "$repo_root/_build/$initrd_name")"
initrd_start="$((initrd_addr))"
initrd_end="$((initrd_start + initrd_size))"

python3 "$repo_root/tools/build_minimal_dtb.py" \
  --timebase-frequency "$timebase_frequency" \
  --initrd-start "$(printf '0x%x' "$initrd_start")" \
  --initrd-end "$(printf '0x%x' "$initrd_end")" \
  > "$repo_root/_build/minimal-alpine.dtb"

printf 'alpine rootfs: %s\n' "$build_dir/$rootfs_name"
printf 'kernel image: %s (%s bytes)\n' \
  "$repo_root/_build/linux-kernel-riscv64" \
  "$(wc -c < "$repo_root/_build/linux-kernel-riscv64")"
printf 'initrd: %s (%s bytes, format=%s, profile=%s, init=%s) @ 0x%x..0x%x\n' \
  "$repo_root/_build/$initrd_name" "$initrd_size" "$initrd_format" "$initrd_profile" "$init_style" \
  "$initrd_start" "$initrd_end"
printf 'initrd gzip: %s (%s bytes)\n' \
  "$repo_root/_build/$initrd_gzip_name" \
  "$(wc -c < "$repo_root/_build/$initrd_gzip_name")"
printf 'dtb: %s\n' "$repo_root/_build/minimal-alpine.dtb"
printf 'timebase-frequency: %s\n' "$timebase_frequency"
