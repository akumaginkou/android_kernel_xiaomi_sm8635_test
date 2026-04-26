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
cp "$IMAGE" "$ANYKERNEL_DIR/Image"
[ -f "$IMAGE_GZ" ] && cp "$IMAGE_GZ" "$ANYKERNEL_DIR/Image.gz"

# AnyKernel3's update-binary runs `busybox --install -s bin` at flash time,
# which requires bin/ to exist. Git doesn't track empty dirs so the upstream
# repo ships without bin/ — create it (with a sentinel so zip preserves it).
mkdir -p "$ANYKERNEL_DIR/bin"
: > "$ANYKERNEL_DIR/bin/.placeholder"

# Replace AnyKernel3's arm32 busybox with Magisk's arm64 static busybox.
# AnyKernel3 ships an arm32 statically-linked busybox built by NDK r15c
# (2017). On some recoveries / kernels without working CONFIG_COMPAT, it
# can't execute and AK3 aborts with "Busybox setup failed". Magisk's
# `lib/arm64-v8a/libbusybox.so` (despite the .so name) is a modern arm64
# static ELF executable — drop it in as tools/busybox.
BB="$ANYKERNEL_DIR/tools/busybox"
echo "[pack] downloading Magisk APK to extract arm64 busybox"
TMP_APK="$(mktemp -t magisk.apk.XXXXXX)"
curl -fsSL -o "$TMP_APK" "$MAGISK_APK_URL"
unzip -p "$TMP_APK" lib/arm64-v8a/libbusybox.so > "$BB"
rm -f "$TMP_APK"
chmod 0755 "$BB"

if [ ! -s "$BB" ] || ! head -c 4 "$BB" | grep -q ELF; then
    echo "[pack] ERROR: $BB missing or not an ELF binary after Magisk extraction." >&2
    ls -l "$ANYKERNEL_DIR/tools" >&2 || true
    exit 1
fi
echo "[pack] busybox: $(file "$BB" | sed 's|^.*: ||')"

# Zip it.
mkdir -p "$OUTDIR"
ZIP_PATH="$OUTDIR/$ZIP_NAME"
( cd "$ANYKERNEL_DIR" && zip -r9 "$ZIP_PATH" . -x '*.git*' 'README.md' '*.zip' )

echo "[pack] wrote $ZIP_PATH"
ls -lh "$ZIP_PATH"
echo "[pack] zip contents (top level):"
unzip -l "$ZIP_PATH" | awk 'NR>3 && $4 !~ "/" {print}' | head -20
unzip -l "$ZIP_PATH" | grep -E "tools/busybox|bin/" | head -10
