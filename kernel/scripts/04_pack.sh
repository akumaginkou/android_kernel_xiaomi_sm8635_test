#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

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

# Sanity-check that the busybox binary is actually present and looks like an
# ELF (catches LFS-pointer-instead-of-blob regressions).
BB="$ANYKERNEL_DIR/tools/busybox"
if [ ! -s "$BB" ] || ! head -c 4 "$BB" | grep -q ELF; then
    echo "[pack] ERROR: $BB missing or not an ELF binary." >&2
    ls -l "$ANYKERNEL_DIR/tools" >&2 || true
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
