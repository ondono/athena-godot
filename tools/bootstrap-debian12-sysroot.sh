#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SYSROOT_DIR="${SYSROOT_DIR:-$REPO_DIR/build/sysroots/debian12-arm64}"
CACHE_DIR="${CACHE_DIR:-$REPO_DIR/build/downloads/debian12-arm64}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-https://deb.debian.org/debian}"
SECURITY_MIRROR="${SECURITY_MIRROR:-https://deb.debian.org/debian-security}"
PACKAGES="${PACKAGES:-libc6 libc6-dev linux-libc-dev libgcc-s1 libgcc-12-dev libstdc++6 libstdc++-12-dev libsqlite3-0 libsqlite3-dev}"

mkdir -p "$SYSROOT_DIR" "$CACHE_DIR/indexes"

for command in curl xz awk sha256sum bsdtar; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Required command not found: $command" >&2
        exit 1
    }
done

download_fresh() {
    url=$1
    out=$2
    tmp="$out.tmp"
    rm -f "$tmp"
    if ! curl -fL "$url" -o "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$out"
}

download_cached() {
    url=$1
    out=$2
    if [ -f "$out" ]; then
        return 0
    fi
    download_fresh "$url" "$out"
}

SECURITY_INDEX="$CACHE_DIR/indexes/bookworm-security-Packages.xz"
UPDATES_INDEX="$CACHE_DIR/indexes/bookworm-updates-Packages.xz"
BASE_INDEX="$CACHE_DIR/indexes/bookworm-Packages.xz"

download_fresh "$SECURITY_MIRROR/dists/bookworm-security/main/binary-arm64/Packages.xz" "$SECURITY_INDEX"
download_fresh "$DEBIAN_MIRROR/dists/bookworm-updates/main/binary-arm64/Packages.xz" "$UPDATES_INDEX"
download_fresh "$DEBIAN_MIRROR/dists/bookworm/main/binary-arm64/Packages.xz" "$BASE_INDEX"

package_entry() {
    index=$1
    package=$2
    xz -dc "$index" | awk -v wanted="$package" '
        BEGIN { RS = ""; FS = "\n" }
        {
            name = ""; filename = ""; checksum = ""
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^Package: /) name = substr($i, 10)
                else if ($i ~ /^Filename: /) filename = substr($i, 11)
                else if ($i ~ /^SHA256: /) checksum = substr($i, 9)
            }
            if (name == wanted && filename != "" && checksum != "") {
                print filename "|" checksum
                exit
            }
        }
    '
}

find_package_entry() {
    package=$1
    for candidate in \
        "$SECURITY_MIRROR|$SECURITY_INDEX" \
        "$DEBIAN_MIRROR|$UPDATES_INDEX" \
        "$DEBIAN_MIRROR|$BASE_INDEX"; do
        mirror=${candidate%%|*}
        index=${candidate#*|}
        entry=$(package_entry "$index" "$package")
        if [ -n "$entry" ]; then
            printf '%s|%s\n' "$mirror" "$entry"
            return 0
        fi
    done
    return 1
}

for package in $PACKAGES; do
    entry=$(find_package_entry "$package" || true)
    if [ -z "$entry" ]; then
        echo "Debian 12 ARM64 package not found: $package" >&2
        exit 1
    fi
    mirror=${entry%%|*}
    remainder=${entry#*|}
    filename=${remainder%%|*}
    checksum=${remainder#*|}
    archive="$CACHE_DIR/$(basename "$filename")"
    download_cached "$mirror/$filename" "$archive"
    if ! printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c - >/dev/null; then
        echo "Checksum failed for $archive" >&2
        exit 1
    fi

    unpack="$CACHE_DIR/.unpack.$$"
    rm -rf "$unpack"
    mkdir -p "$unpack"
    bsdtar -xf "$archive" -C "$unpack"
    data_archive=$(find "$unpack" -maxdepth 1 -type f -name 'data.tar.*' -print | head -n 1)
    if [ -z "$data_archive" ]; then
        echo "Debian data archive missing in $archive" >&2
        rm -rf "$unpack"
        exit 1
    fi
    bsdtar -xpf "$data_archive" -C "$SYSROOT_DIR"
    rm -rf "$unpack"
    echo "installed $package into Debian 12 ARM64 sysroot"
done

cat > "$SYSROOT_DIR/athena-debian12-arm64-env.sh" <<EOF
export ATHENA_AARCH64_SYSROOT="$SYSROOT_DIR"
export ATHENA_AARCH64_TARGET="aarch64-linux-gnu"
export ATHENA_TARGET_GLIBC_VERSION="2.36"
EOF

echo "Debian 12 ARM64 sysroot ready: $SYSROOT_DIR"
