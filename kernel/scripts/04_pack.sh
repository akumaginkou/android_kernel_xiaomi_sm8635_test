#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

# Pin a known-good Magisk release whose lib/arm64-v8a/libbusybox.so is a
# modern statically-linked arm64 busybox (NDK r27b+). We use this to
# replace AnyKernel3's bundled arm32 busybox, which fails on some
# recoveries with "Busybox setup failed" because the arm32 binary
# can't execute (CONFIG_COMPAT may be off, or the recovery context
# blocks 32-bit exec).
MAGISK_APK_URL="${MAGISK_APK_URL:-https://github.com/topjohnwu/Magisk/releases/download/v30.7/Magisk-v30.7.apk}"

IMAGE="$KERNEL_DIR/out/arch/arm64/boot/Image"
IMAGE_GZ="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"

if [ ! -f "$IMAGE" ]; then
    echo "[pack] ERROR: $IMAGE not found. Run 03_build.sh first." >&2
    exit 1
fi

# Reset AnyKernel3 to a clean state.
git -C "$ANYKERNEL_DIR" clean -fdx
git -C "$ANYKERNEL_DIR" checkout -f

# Overlay our peridot anykernel.sh.
PERIDOT_AK_CONF="$PROJECT_ROOT/kernel/anykernel/anykernel.sh"
if [ -f "$PERIDOT_AK_CONF" ]; then
    echo "[pack] using peridot anykernel.sh override"
    cp "$PERIDOT_AK_CONF" "$ANYKERNEL_DIR/anykernel.sh"
fi

# Drop the kernel binary into AnyKernel3.
# CRITICAL: peridot's stock boot.img has KERNEL_FMT [raw] (uncompressed
# Image, ~35 MB). magiskboot keeps the original format flag in the
# header even after repack, so if we ship Image.gz the device ends up
# with KERNEL_FMT=raw header + gz payload -> bootloader tries to exec
# gz data as raw kernel -> instant boot loop.
# Always ship the uncompressed `Image` to match the stock format.
echo "[pack] using raw Image (peridot boot.img expects KERNEL_FMT=raw)"
cp "$IMAGE" "$ANYKERNEL_DIR/Image"
rm -f "$ANYKERNEL_DIR/Image.gz"  # ensure no .gz fallback wins AK3's lookup

# AnyKernel3's update-binary runs `busybox --install -s bin` at flash time,
# which requires bin/ to exist. Git doesn't track empty dirs so the upstream
# repo ships without bin/ — create it (with a sentinel so zip preserves it).
mkdir -p "$ANYKERNEL_DIR/bin"
: > "$ANYKERNEL_DIR/bin/.placeholder"

# AnyKernel3 ships arm32 statically-linked tools (NDK r15c, 2017). TWRP
# on peridot rejects 32-bit binaries with errors like
#   "/tmp/anykernel/tools/busybox: not executable: 32-bit ELF file"
#   "magiskboot: line 1: syntax error"  (sh tries to interpret the ELF)
# Replace BOTH busybox and magiskboot with Magisk's arm64 versions
# (extracted from the latest Magisk APK; lib/arm64-v8a/lib*.so are
# actually statically-linked arm64 ELF executables — Magisk masquerades
# them as .so so they can be packed inside an APK).
echo "[pack] downloading Magisk APK to extract arm64 binaries"
TMP_APK="$(mktemp -t magisk.apk.XXXXXX)"
curl -fsSL -o "$TMP_APK" "$MAGISK_APK_URL"
for pair in busybox:libbusybox.so magiskboot:libmagiskboot.so magiskpolicy:libmagiskpolicy.so; do
    name="${pair%%:*}"
    so="${pair##*:}"
    dst="$ANYKERNEL_DIR/tools/$name"
    if unzip -p "$TMP_APK" "lib/arm64-v8a/$so" > "$dst" 2>/dev/null && [ -s "$dst" ]; then
        chmod 0755 "$dst"
        echo "[pack]   replaced tools/$name with arm64: $(file "$dst" | sed 's|^.*: ||')"
    else
        echo "[pack] WARNING: failed to extract lib/arm64-v8a/$so" >&2
    fi
done
rm -f "$TMP_APK"

BB="$ANYKERNEL_DIR/tools/busybox"
if [ ! -s "$BB" ] || ! head -c 4 "$BB" | grep -q ELF; then
    echo "[pack] ERROR: $BB missing or not an ELF binary after Magisk extraction." >&2
    exit 1
fi

# Zip it.
mkdir -p "$OUTDIR"
ZIP_PATH="$OUTDIR/$ZIP_NAME"
( cd "$ANYKERNEL_DIR" && zip -r9 "$ZIP_PATH" . -x '*.git*' 'README.md' '*.zip' )

echo "[pack] wrote $ZIP_PATH"
ls -lh "$ZIP_PATH"
echo "[pack] zip contents (top level):"
unzip -l "$ZIP_PATH" | awk 'NR>3 && $4 !~ "/" {print}' | head -20
unzip -l "$ZIP_PATH" | grep -E "tools/busybox|bin/" | head -10
