#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$repo_root/_build/alpine-rootfs"
version="${ALPINE_VERSION:-3.24.1}"
arch="${ALPINE_ARCH:-riscv64}"
base_url="${ALPINE_BASE_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/$arch}"
apk_repo_base_url="${ALPINE_APK_REPO_BASE_URL:-https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/$arch}"
apkindex_url="${ALPINE_APKINDEX_URL:-$apk_repo_base_url/APKINDEX.tar.gz}"
apkindex_path="$build_dir/APKINDEX.tar.gz"
include_apk_static="${ALPINE_INCLUDE_APK_STATIC:-1}"
offline_apk_packages="${ALPINE_OFFLINE_APK_PACKAGES:-ddate}"
rootfs_name="alpine-minirootfs-$version-$arch.tar.gz"
rootfs_url="$base_url/$rootfs_name"
sha_url="$rootfs_url.sha256"
image_path="${ALPINE_ROOTFS_IMAGE:-$repo_root/_build/alpine-rootfs-$arch.ext4}"
image_size="${ALPINE_ROOTFS_IMAGE_SIZE:-64M}"

mkdir -p "$build_dir" "$repo_root/_build"

apkindex_content=""

ensure_apkindex_content() {
  if [[ -z "$apkindex_content" ]]; then
    if [[ ! -f "$apkindex_path" ]]; then
      curl -L -o "$apkindex_path" "$apkindex_url"
    fi
    apkindex_content="$(tar -xOzf "$apkindex_path" APKINDEX)"
  fi
}

apk_package_version() {
  local package_name="$1"
  ensure_apkindex_content
  awk -v package_name="$package_name" 'BEGIN{RS="\n\n"} $0 ~ "(^|\n)P:" package_name "(\n|$)" { for (i = 1; i <= NF; i++) if ($i ~ /^V:/) { sub(/^V:/, "", $i); print $i; exit } }' <<< "$apkindex_content"
}

download_main_apk() {
  local package_name="$1"
  local package_version
  package_version="$(apk_package_version "$package_name")"
  if [[ -z "$package_version" ]]; then
    printf '%s not found in %s\n' "$package_name" "$apkindex_url" >&2
    exit 1
  fi
  local apk_path="$build_dir/$package_name-$package_version.apk"
  if [[ ! -f "$apk_path" ]]; then
    curl -L -o "$apk_path" "$apk_repo_base_url/$package_name-$package_version.apk"
  fi
  printf '%s\n' "$apk_path"
}

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

if [[ "$include_apk_static" == "1" ]]; then
  apk_tools_static_apk="$(download_main_apk apk-tools-static)"
  tar --warning=no-unknown-keyword -xzf "$apk_tools_static_apk" -C "$root_dir" sbin/apk.static
  chmod +x "$root_dir/sbin/apk.static"
fi

if [[ -n "$offline_apk_packages" ]]; then
  mkdir -p "$root_dir/root/riscv-mbt-apks"
  mkdir -p "$root_dir/root/riscv-mbt-apks/$arch"
  ensure_apkindex_content
  cp "$apkindex_path" "$root_dir/root/riscv-mbt-apks/APKINDEX.tar.gz"
  cp "$apkindex_path" "$root_dir/root/riscv-mbt-apks/$arch/APKINDEX.tar.gz"
  for package_name in $offline_apk_packages; do
    package_apk="$(download_main_apk "$package_name")"
    cp "$package_apk" "$root_dir/root/riscv-mbt-apks/$package_name.apk"
    cp "$package_apk" "$root_dir/root/riscv-mbt-apks/$arch/$package_name.apk"
  done
fi

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
