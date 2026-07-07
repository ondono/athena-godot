#!/usr/bin/env sh
set -eu

max_glibc=""

if [ "${1:-}" = "--max-glibc" ]; then
    if [ "$#" -lt 3 ]; then
        echo "usage: $0 [--max-glibc <version>] <shared-library> [<shared-library> ...]" >&2
        exit 2
    fi
    max_glibc=$2
    shift 2
fi

if [ "$#" -lt 1 ]; then
    echo "usage: $0 [--max-glibc <version>] <shared-library> [<shared-library> ...]" >&2
    exit 2
fi

for command in readelf objdump ldd awk sort; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "Required command not found: $command" >&2
        exit 1
    }
done

failed=0

is_foreign_elf() {
    machine=$(readelf -h "$1" 2>/dev/null | awk -F: '/Machine:/ { sub(/^[ \t]+/, "", $2); print $2; exit }')
    host_machine=$(uname -m)

    case "$machine" in
        *X86-64*|*x86-64*|*x86_64*)
            case "$host_machine" in
                x86_64|amd64) return 1 ;;
            esac
            ;;
        *AArch64*|*aarch64*|*ARM64*)
            case "$host_machine" in
                aarch64|arm64) return 1 ;;
            esac
            ;;
    esac

    [ -n "$machine" ]
}

version_gt() {
    highest=$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)
    [ "$highest" = "$1" ] && [ "$1" != "$2" ]
}

for library in "$@"; do
    if [ ! -f "$library" ]; then
        echo "ABI check input missing: $library" >&2
        failed=1
        continue
    fi

    echo "== $library =="
    readelf_output=$(readelf -Ws "$library")
    objdump_output=$(objdump -T "$library")

    if printf '%s\n%s\n' "$readelf_output" "$objdump_output" | grep -q 'GLIBC_PRIVATE'; then
        echo "error: $library references GLIBC_PRIVATE" >&2
        failed=1
    fi

    glibc_versions=$(printf '%s\n%s\n' "$readelf_output" "$objdump_output" \
        | awk 'match($0, /GLIBC_[0-9]+(\.[0-9]+)*/) { print substr($0, RSTART, RLENGTH) }' \
        | sort -Vu \
        || true)
    echo "Required GLIBC symbol versions:"
    printf '%s\n' "$glibc_versions"

    if [ -n "$max_glibc" ]; then
        for glibc_version in $glibc_versions; do
            version=${glibc_version#GLIBC_}
            if version_gt "$version" "$max_glibc"; then
                echo "error: $library requires $glibc_version, newer than GLIBC_$max_glibc" >&2
                failed=1
            fi
        done
    fi

    echo "ldd version report:"
    if ! ldd -v "$library"; then
        if is_foreign_elf "$library"; then
            echo "warning: ldd -v skipped for foreign-architecture ELF: $library" >&2
        else
            echo "warning: ldd -v failed for $library" >&2
            failed=1
        fi
    fi
done

exit "$failed"
