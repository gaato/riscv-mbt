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
image_path="${ALPINE_ROOTFS_IMAGE:-$repo_root/_build/alpine-rootfs-$arch.ext4}"
image_size="${ALPINE_ROOTFS_IMAGE_SIZE:-64M}"

mkdir -p "$build_dir" "$repo_root/_build"

if [[ ! -f "$build_dir/$rootfs_name" ]]; then
  curl -L -o "$build_dir/$rootfs_name" "$rootfs_url"
fi

curl -L -o "$build_dir/$rootfs_name.sha256" "$sha_url"
(
  cd "$build_dir"
  sha256sum -c "$rootfs_name.sha256"
)

root_dir="$(mktemp -d "$repo_root/_build/alpine-rootfs-image.XXXXXX")"
trap 'rm -rf "$root_dir"' EXIT

tar -xzf "$build_dir/$rootfs_name" -C "$root_dir"
mkdir -p "$root_dir"/proc "$root_dir"/sys "$root_dir"/dev "$root_dir"/tmp "$root_dir"/root
mkdir -p "$root_dir"/run
cat > "$root_dir/sbin/riscv-mbt-autoshell" <<'EOF'
#!/bin/sh
printf 'post-init-ready\n'
exec /bin/sh
EOF
chmod +x "$root_dir/sbin/riscv-mbt-autoshell"
cat > "$root_dir/etc/fstab" <<'EOF'
proc /proc proc defaults 0 0
sysfs /sys sysfs defaults 0 0
devtmpfs /dev devtmpfs defaults 0 0
tmpfs /run tmpfs defaults 0 0
tmpfs /tmp tmpfs defaults 0 0
EOF
cat > "$root_dir/etc/inittab" <<'EOF'
::sysinit:/bin/mount -t proc proc /proc
::sysinit:/bin/mount -t sysfs sysfs /sys
::sysinit:/bin/mount -t devtmpfs devtmpfs /dev
::sysinit:/bin/mount -t tmpfs tmpfs /run
::sysinit:/bin/mount -t tmpfs tmpfs /tmp
ttyS0::respawn:/sbin/riscv-mbt-autoshell
::shutdown:/bin/umount -a -r
EOF

rm -f "$image_path"
truncate -s "$image_size" "$image_path"
/usr/sbin/mke2fs -q -t ext4 -L alpine-riscv -d "$root_dir" "$image_path"

printf 'alpine rootfs: %s\n' "$build_dir/$rootfs_name"
printf 'rootfs image: %s (%s bytes)\n' "$image_path" "$(wc -c < "$image_path")"
