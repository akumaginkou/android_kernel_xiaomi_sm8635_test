#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

cd "$KERNEL_DIR"

# ---- 1. Install ReSukiSU ---------------------------------------------------
# setup.sh clones ReSukiSU into KernelSU/, symlinks drivers/kernelsu, and
# patches drivers/Makefile + drivers/Kconfig. Provides the KSU-side
# ksu_handle_* implementations.
if [ ! -d KernelSU ]; then
    echo "[patch] installing ReSukiSU ($RESUKISU_TAG)"
    curl -LSs "$RESUKISU_INSTALLER" | bash -s "$RESUKISU_TAG"
else
    echo "[patch] ReSukiSU already present, skipping installer"
fi

ACTUAL_REF="$(git -C KernelSU rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
[ "$ACTUAL_REF" = "HEAD" ] && ACTUAL_REF="$(git -C KernelSU rev-parse --short HEAD)"
echo "[patch] ReSukiSU on $ACTUAL_REF"

if ! grep -q "config KSU_SUSFS" KernelSU/kernel/Kconfig 2>/dev/null; then
    echo "[patch] ERROR: KSU_SUSFS Kconfig not found in ReSukiSU/kernel/Kconfig" >&2
    exit 1
fi
echo "[patch] ReSukiSU SUSFS Kconfig present"

# ---- 2. Apply SUSFS kernel-side patch + source overlay ---------------------
# susfs4ksu's gki-android14-6.1 HEAD adds:
#   - linux/susfs.h, fs/susfs.c (SUSFS implementation)
#   - inline ksu_handle_* calls in fs/exec.c, fs/open.c, fs/read_write.c,
#     fs/stat.c, drivers/input/input.c, kernel/reboot.c, kernel/sys.c
#     (ALL seven hooks ReSukiSU's inline_hook_check.mk requires)
# Symbols are resolved by ReSukiSU's KSU side at link time.
SUSFS_PATCHES="$SUSFS_DIR/kernel_patches"
KERNEL_PATCH="$SUSFS_PATCHES/50_add_susfs_in_gki-android14-6.1.patch"

if [ ! -f "$KERNEL_PATCH" ]; then
    echo "[patch] ERROR: $KERNEL_PATCH not found." >&2
    exit 1
fi

if grep -q "susfs" fs/Makefile 2>/dev/null && [ -f fs/susfs.c ]; then
    echo "[patch] SUSFS kernel patch already applied, skipping"
else
    echo "[patch] applying $KERNEL_PATCH"
    cp "$KERNEL_PATCH" ./
    git apply --check "$(basename "$KERNEL_PATCH")"
    git apply "$(basename "$KERNEL_PATCH")"
fi

for d in fs include/linux; do
    if [ -d "$SUSFS_PATCHES/$d" ]; then
        echo "[patch] copying $SUSFS_PATCHES/$d/ -> $d/"
        cp -r "$SUSFS_PATCHES/$d/." "$d/"
    fi
done

if [ ! -f include/linux/susfs.h ]; then
    echo "[patch] ERROR: include/linux/susfs.h missing after SUSFS overlay." >&2
    exit 1
fi
echo "[patch] SUSFS_VERSION in tree: $(grep '^#define SUSFS_VERSION' include/linux/susfs.h | awk '{print $3}')"

# ---- 3. Verify all 7 ksu_handle_* hooks landed -----------------------------
# Pre-check what ReSukiSU's inline_hook_check.mk will look for, so we
# fail fast at the patch step rather than deep into the build.
declare -a REQUIRED_HOOKS=(
    "ksu_handle_setresuid:kernel/sys.c"
    "ksu_handle_execveat:fs/exec.c"
    "ksu_handle_faccessat:fs/open.c"
    "ksu_handle_sys_read:fs/read_write.c"
    "ksu_handle_stat:fs/stat.c"
    "ksu_handle_sys_reboot:kernel/reboot.c"
    "ksu_handle_input_handle_event:drivers/input/input.c"
)
MISSING=0
for entry in "${REQUIRED_HOOKS[@]}"; do
    sym="${entry%%:*}"
    file="${entry##*:}"
    if grep -q "$sym" "$file" 2>/dev/null; then
        echo "[patch] OK: $sym in $file"
    else
        echo "[patch] MISSING: $sym in $file" >&2
        MISSING=1
    fi
done
if [ "$MISSING" -ne 0 ]; then
    echo "[patch] ERROR: one or more ReSukiSU-required hooks not added by susfs4ksu." >&2
    exit 1
fi

echo "[patch] done."
