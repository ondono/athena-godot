#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

SYSROOT_DIR="${SYSROOT_DIR:-$REPO_DIR/build/sysroots/archlinuxarm-aarch64}"
CACHE_DIR="${CACHE_DIR:-$REPO_DIR/build/downloads/archlinuxarm-aarch64}"
MIRROR_URL="${MIRROR_URL:-http://os.archlinuxarm.org/aarch64}"
PACKAGES="${PACKAGES:-filesystem linux-api-headers glibc libgcc libstdc++ gcc}"

mkdir -p "$SYSROOT_DIR" "$CACHE_DIR"

download() {
    url=$1
    out=$2
    if [ -f "$out" ]; then
        return
    fi
    tmp="$out.tmp"
    rm -f "$tmp"
    curl -fL "$url" -o "$tmp"
    mv "$tmp" "$out"
}

refresh_db() {
    repo=$1
    db="$CACHE_DIR/$repo.db"
    download "$MIRROR_URL/$repo/$repo.db" "$db"
    index_dir="$CACHE_DIR/db/$repo"
    if [ ! -d "$index_dir" ]; then
        mkdir -p "$index_dir"
        bsdtar -xf "$db" -C "$index_dir"
    fi
}

package_filename() {
    repo=$1
    name=$2
    index_dir="$CACHE_DIR/db/$repo"
    find "$index_dir" -mindepth 2 -maxdepth 2 -name desc -print | while IFS= read -r desc_path; do
        desc_name=$(awk 'previous == "%NAME%" { print; exit } { previous = $0 }' "$desc_path")
        if [ "$desc_name" = "$name" ]; then
            awk 'previous == "%FILENAME%" { print; exit } { previous = $0 }' "$desc_path"
            exit 0
        fi
    done
}

download_package() {
    repo=$1
    name=$2
    filename=$(package_filename "$repo" "$name")
    if [ -z "$filename" ]; then
        return 1
    fi

    archive="$CACHE_DIR/$filename"
    download "$MIRROR_URL/$repo/$filename" "$archive"
    bsdtar -xpf "$archive" -C "$SYSROOT_DIR"
    return 0
}

refresh_db core
refresh_db extra

for package in $PACKAGES; do
    if download_package core "$package"; then
        echo "installed $package from core"
    elif download_package extra "$package"; then
        echo "installed $package from extra"
    else
        echo "could not find package: $package" >&2
        exit 1
    fi
done

cat > "$SYSROOT_DIR/athena-rockpi-env.sh" <<EOF
export ATHENA_AARCH64_SYSROOT="$SYSROOT_DIR"
export ATHENA_AARCH64_TARGET="aarch64-unknown-linux-gnu"
EOF

echo "Rock Pi sysroot ready: $SYSROOT_DIR"
echo "Use: . \"$SYSROOT_DIR/athena-rockpi-env.sh\" && ./build-rockpi.sh"
