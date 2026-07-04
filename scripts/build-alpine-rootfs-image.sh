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
local_apkindex_path="$build_dir/APKINDEX-local-$arch.tar.gz"
include_apk_static="${ALPINE_INCLUDE_APK_STATIC:-1}"
offline_apk_packages="${ALPINE_OFFLINE_APK_PACKAGES:-ddate iputils}"
rootfs_name="alpine-minirootfs-$version-$arch.tar.gz"
rootfs_url="$base_url/$rootfs_name"
sha_url="$rootfs_url.sha256"
image_path="${ALPINE_ROOTFS_IMAGE:-$repo_root/_build/alpine-rootfs-$arch.ext4}"
image_size="${ALPINE_ROOTFS_IMAGE_SIZE:-64M}"

mkdir -p "$build_dir" "$repo_root/_build"

apkindex_content=""
resolved_offline_apk_packages=()
declare -A resolved_offline_apk_package_seen=()

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

apk_package_record() {
  local package_name="$1"
  ensure_apkindex_content
  awk -v package_name="$package_name" 'BEGIN{RS="\n\n"} $0 ~ "(^|\n)P:" package_name "(\n|$)" { print; exit }' <<< "$apkindex_content"
}

apk_provider_package() {
  local dependency_name="$1"
  ensure_apkindex_content
  awk -v dependency_name="$dependency_name" '
    BEGIN { RS="\n\n" }
    $0 ~ "(^|\n)p:([^ \n]* )*" dependency_name "=" {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^P:/) {
          sub(/^P:/, "", $i)
          print $i
          exit
        }
      }
    }
  ' <<< "$apkindex_content"
}

apk_record_dependencies() {
  local package_record="$1"
  awk '
    /^D:/ {
      sub(/^D:/, "")
      for (i = 1; i <= NF; i++) print $i
    }
  ' <<< "$package_record"
}

apk_dependency_base_name() {
  local dependency_name="$1"
  dependency_name="${dependency_name%%[<>=~]*}"
  printf '%s\n' "$dependency_name"
}

resolve_offline_apk_package() {
  local package_name="$1"
  if [[ -n "${resolved_offline_apk_package_seen[$package_name]:-}" ]]; then
    return
  fi
  local package_record
  package_record="$(apk_package_record "$package_name")"
  if [[ -z "$package_record" ]]; then
    printf '%s not found in %s\n' "$package_name" "$apkindex_url" >&2
    exit 1
  fi
  resolved_offline_apk_package_seen[$package_name]=1
  resolved_offline_apk_packages+=("$package_name")
  while IFS= read -r dependency_name; do
    if [[ -z "$dependency_name" ]]; then
      continue
    fi
    local dependency_base_name
    dependency_base_name="$(apk_dependency_base_name "$dependency_name")"
    if [[ -n "$(apk_package_record "$dependency_base_name")" ]]; then
      resolve_offline_apk_package "$dependency_base_name"
      continue
    fi
    local provider_package
    provider_package="$(apk_provider_package "$dependency_base_name")"
    if [[ -n "$provider_package" ]]; then
      resolve_offline_apk_package "$provider_package"
    fi
  done < <(apk_record_dependencies "$package_record")
}

resolve_offline_apk_packages() {
  resolved_offline_apk_packages=()
  resolved_offline_apk_package_seen=()
  for package_name in $offline_apk_packages; do
    resolve_offline_apk_package "$package_name"
  done
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

write_local_apkindex() {
  local index_dir="$1"
  rm -rf "$index_dir"
  mkdir -p "$index_dir"
  : > "$index_dir/APKINDEX"
  ensure_apkindex_content
  for package_name in "${resolved_offline_apk_packages[@]}"; do
    local package_record
    package_record="$(apk_package_record "$package_name")"
    if [[ -z "$package_record" ]]; then
      printf '%s not found in %s\n' "$package_name" "$apkindex_url" >&2
      exit 1
    fi
    printf '%s\n\n' "$package_record" >> "$index_dir/APKINDEX"
  done
  (
    cd "$index_dir"
    tar -czf "$local_apkindex_path" APKINDEX
  )
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
  resolve_offline_apk_packages
  local_index_dir="$build_dir/local-apkindex"
  write_local_apkindex "$local_index_dir"
  cp "$local_apkindex_path" "$root_dir/root/riscv-mbt-apks/APKINDEX.tar.gz"
  cp "$local_apkindex_path" "$root_dir/root/riscv-mbt-apks/$arch/APKINDEX.tar.gz"
  for package_name in "${resolved_offline_apk_packages[@]}"; do
    package_apk="$(download_main_apk "$package_name")"
    package_apk_name="$(basename "$package_apk")"
    cp "$package_apk" "$root_dir/root/riscv-mbt-apks/$package_name.apk"
    cp "$package_apk" "$root_dir/root/riscv-mbt-apks/$arch/$package_name.apk"
    cp "$package_apk" "$root_dir/root/riscv-mbt-apks/$package_apk_name"
    cp "$package_apk" "$root_dir/root/riscv-mbt-apks/$arch/$package_apk_name"
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
