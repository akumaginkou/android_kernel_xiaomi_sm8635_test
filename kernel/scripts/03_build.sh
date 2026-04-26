#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

JOBS="${JOBS:-$(nproc)}"
FRAGMENT_DIR="$PROJECT_ROOT/kernel/config"

cd "$KERNEL_DIR"

# ---- Toolchain: pull AOSP-equivalent clang prebuilt if not already present ----
# peridot's stock kernel was built with AOSP clang 21.0.0; Ubuntu's
# system clang-18 produces a kernel that fails to boot on real hardware
# (verified with PURE rebuild). ZyCromerZ/Clang publishes AOSP-derived
# clang 21.x tarballs on GitHub releases — closest reproducible match.
if [ -n "${CLANG_DIR:-}" ] && [ ! -x "$CLANG_DIR/bin/clang" ]; then
    echo "[build] AOSP-equivalent clang not cached, fetching latest from $CLANG_REPO ..."
    mkdir -p "$CLANG_DIR"
    # Auth header lifts api.github.com 60 req/hr anonymous limit (CI runners
    # share IPs; rate-limit hits flake unauthenticated builds).
    AUTH_HDR=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        AUTH_HDR=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    # ZyCromerZ alternates clang 15.x (LTS) and clang 23.x (git-tip) builds.
    # peridot's vendor_dlkm modules require CFI_CLANG=y at the ABI level
    # (CFI changes indirect-call signatures); CFI_CLANG depends on
    # cc-option=-fsanitize=kcfi which needs clang >= 17.
    # clang 15 was producing CFI=n kernels that vendor modules then refused
    # to bind to. Use clang 23 git-tip (closest to stock's clang 21).
    CLANG_MAJOR="${CLANG_MAJOR:-23}"
    ASSET_URL="$(curl -fsSL "${AUTH_HDR[@]}" \
        "https://api.github.com/repos/${CLANG_REPO}/releases?per_page=30" \
        | grep '"browser_download_url"' \
        | grep -oE '"https://[^"]*Clang-'"${CLANG_MAJOR}"'\.[^"]*\.tar\.(gz|xz)"' \
        | head -1 | tr -d '"')"
    if [ -z "$ASSET_URL" ]; then
        echo "[build] ERROR: could not resolve $CLANG_REPO latest release tarball" >&2
        exit 1
    fi
    echo "[build] downloading $ASSET_URL"
    TMP_TAR="$(mktemp -t clang.tar.XXXXXX)"
    curl -fsSL -o "$TMP_TAR" "$ASSET_URL"
    case "$ASSET_URL" in
        *.tar.gz) tar xzf "$TMP_TAR" -C "$CLANG_DIR" ;;
        *.tar.xz) tar xJf "$TMP_TAR" -C "$CLANG_DIR" ;;
    esac
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
