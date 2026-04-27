#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

JOBS="${JOBS:-$(nproc)}"
FRAGMENT_DIR="$PROJECT_ROOT/kernel/config"

cd "$KERNEL_DIR"

# ---- Toolchain: pull AOSP-genuine clang prebuilt ----
# topnotchfreaks/clang mirrors AOSP's internal `prebuilts/clang/host/
# linux-x86/clang-r*` builds on GitHub releases (the AOSP googlesource
# +archive endpoint reliably 400/404s for these specific subtrees).
# Tarballs unpack flat — bin/, lib/, include/ at the top level — so no
# strip-components.
if [ -n "${CLANG_DIR:-}" ] && [ ! -x "$CLANG_DIR/bin/clang" ]; then
    echo "[build] AOSP clang ${CLANG_BUILD} not cached, downloading ..."
    mkdir -p "$CLANG_DIR"
    TMP_TAR="$(mktemp -t aosp-clang.tar.XXXXXX)"
    echo "[build] curl -fsSL $CLANG_TARBALL_URL  (~1 GB, expect ~30s on GHA)"
    curl -fsSL -o "$TMP_TAR" "$CLANG_TARBALL_URL"
    tar xzf "$TMP_TAR" -C "$CLANG_DIR"
    rm -f "$TMP_TAR"
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

# Base config selection.
#
# `gki_defconfig + vendor/peridot_GKI.config` does NOT enable the SoC-specific
# drivers peridot needs (CONFIG_ARCH_CLIFFS, CONFIG_QRTR, CONFIG_CFG80211,
# CONFIG_ARM_QCOM_CPUFREQ_HW, etc.) — verified by extracting CONFIG_IKCONFIG
# from the shipped EvolutionX boot.img and diff'ing against our built kernel.
# Stock has ~8700 config lines; our defconfig+fragment only produced ~7800.
#
# To reproduce stock's actual driver set we now seed out/.config with the
# extracted stock config (kernel/config/stock_base.config) and let
# olddefconfig fix up any compiler-version-dependent symbols (CFI_CLANG,
# CLANG_VERSION, AS_VERSION, etc.) before merging our fragments on top.
STOCK_BASE="$FRAGMENT_DIR/stock_base.config"
if [ -f "$STOCK_BASE" ]; then
    echo "[build] using extracted stock base config: $STOCK_BASE"
    mkdir -p out
    cp "$STOCK_BASE" out/.config
    make "${MAKE_ARGS[@]}" olddefconfig
else
    echo "[build] make $DEFCONFIG $VENDOR_DEFCONFIG"
    make "${MAKE_ARGS[@]}" "$DEFCONFIG" "$VENDOR_DEFCONFIG"
fi

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
