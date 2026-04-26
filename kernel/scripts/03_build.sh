#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

JOBS="${JOBS:-$(nproc)}"
FRAGMENT_DIR="$PROJECT_ROOT/kernel/config"

cd "$KERNEL_DIR"

# Honor an external clang prebuilt if CLANG_DIR points at one.
if [ -n "${CLANG_DIR:-}" ] && [ -x "$CLANG_DIR/bin/clang" ]; then
    export PATH="$CLANG_DIR/bin:$PATH"
    echo "[build] using clang from $CLANG_DIR"
fi

clang --version | head -1

MAKE_ARGS=(
    -j"$JOBS"
    O=out
    ARCH="$ARCH"
    LLVM=1 LLVM_IAS=1
    CC="${CC}"
    HOSTCC="${CC}"
    LD=ld.lld
    AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump
    STRIP=llvm-strip READELF=llvm-readelf
)

if [ "${USE_CCACHE}" = "1" ] && command -v ccache >/dev/null 2>&1; then
    ccache -M "$CCACHE_MAXSIZE" >/dev/null
    MAKE_ARGS+=(CC="ccache ${CC}" HOSTCC="ccache ${CC}")
    echo "[build] ccache enabled (dir=$CCACHE_DIR, max=$CCACHE_MAXSIZE)"
fi

# Generate base config from gki_defconfig + peridot vendor fragment.
echo "[build] make $DEFCONFIG $VENDOR_DEFCONFIG"
make "${MAKE_ARGS[@]}" "$DEFCONFIG" "$VENDOR_DEFCONFIG"

# Merge every *.fragment in kernel/config/ on top of the base .config.
# Files are applied in lexical order (00_*, ksu_*, extras_*, ...), so name
# them accordingly if you need a specific override order.
shopt -s nullglob
FRAGMENTS=( "$FRAGMENT_DIR"/*.fragment )
shopt -u nullglob
if [ "${#FRAGMENTS[@]}" -gt 0 ]; then
    echo "[build] merging ${#FRAGMENTS[@]} fragment(s):"
    for f in "${FRAGMENTS[@]}"; do echo "          - $(basename "$f")"; done
    ./scripts/kconfig/merge_config.sh -m -O out out/.config "${FRAGMENTS[@]}"
    make "${MAKE_ARGS[@]}" olddefconfig
else
    echo "[build] no fragments found in $FRAGMENT_DIR"
fi

# Build Image (and Image.gz / dtbs) — sufficient for AnyKernel3 packaging.
echo "[build] building Image"
make "${MAKE_ARGS[@]}" Image

if [ -f out/arch/arm64/boot/Image.gz ]; then
    :
else
    make "${MAKE_ARGS[@]}" Image.gz || true
fi

ls -lh out/arch/arm64/boot/Image* 2>&1 || true
echo "[build] done."
