#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

JOBS="${JOBS:-$(nproc)}"
FRAGMENT_DIR="$PROJECT_ROOT/kernel/config"

cd "$KERNEL_DIR"

# ---- Toolchain: download AOSP clang prebuilt if not already present ----
# peridot's stock kernel was built with AOSP clang 21 (banner says
# r563880c); the system Ubuntu clang-18 produces a kernel that fails
# to boot on real hardware. Pull AOSP clang into $CLANG_DIR.
if [ -n "${CLANG_DIR:-}" ] && [ ! -x "$CLANG_DIR/bin/clang" ] && [ -n "${AOSP_CLANG_VERSION:-}" ]; then
    echo "[build] AOSP clang $AOSP_CLANG_VERSION not cached, downloading..."
    mkdir -p "$CLANG_DIR"
    # AOSP googlesource +archive endpoint serves any subtree as a tarball.
    URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-${AOSP_CLANG_VERSION}.tar.gz"
    if ! curl -fsSL "$URL" | tar xz -C "$CLANG_DIR" 2>/dev/null; then
        # Fallback: shallow git clone via sparse-checkout (for when the +archive
        # endpoint rate-limits or returns HTML on misses)
        echo "[build] +archive download failed, falling back to sparse git clone"
        SPARSE_DIR="$WORKDIR/aosp-clang-src"
        rm -rf "$SPARSE_DIR"
        git clone --depth=1 --filter=blob:none --no-checkout \
            https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
            "$SPARSE_DIR"
        git -C "$SPARSE_DIR" sparse-checkout init --no-cone
        git -C "$SPARSE_DIR" sparse-checkout set "clang-${AOSP_CLANG_VERSION}/*"
        git -C "$SPARSE_DIR" checkout
        rm -rf "$CLANG_DIR"
        mv "$SPARSE_DIR/clang-${AOSP_CLANG_VERSION}" "$CLANG_DIR"
    fi
    chmod -R +x "$CLANG_DIR/bin" 2>/dev/null || true
fi

if [ -n "${CLANG_DIR:-}" ] && [ -x "$CLANG_DIR/bin/clang" ]; then
    export PATH="$CLANG_DIR/bin:$PATH"
    echo "[build] using clang from $CLANG_DIR"
else
    echo "[build] WARNING: AOSP clang unavailable, falling back to system clang"
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
