#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

cd "$KERNEL_DIR"

# ---- 1. Install KernelSU-Next ----------------------------------------------
# The official setup.sh adds drivers/kernelsu and patches Makefile/Kconfig.
# KSU_NEXT_TAG must be a real branch name (e.g. next-susfs-a14-6.1-dev for
# kernel 6.1). setup.sh silently falls back to the default branch on a bad
# ref; we verify below to fail loudly instead.
if [ ! -d KernelSU-Next ]; then
    echo "[patch] installing KernelSU-Next ($KSU_NEXT_TAG)"
    curl -LSs "$KSU_NEXT_INSTALLER" | bash -s "$KSU_NEXT_TAG"
else
    echo "[patch] KernelSU-Next already present, skipping installer"
fi

ACTUAL_BRANCH="$(git -C KernelSU-Next rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
if [ "$ACTUAL_BRANCH" != "$KSU_NEXT_TAG" ]; then
    echo "[patch] ERROR: KernelSU-Next is on '$ACTUAL_BRANCH', expected '$KSU_NEXT_TAG'." >&2
    echo "[patch] setup.sh silently fell back. Verify '$KSU_NEXT_TAG' exists in KernelSU-Next." >&2
    exit 1
fi
echo "[patch] KernelSU-Next on branch $ACTUAL_BRANCH"

# ---- 2. Apply SUSFS kernel-side patch --------------------------------------
SUSFS_PATCHES="$SUSFS_DIR/kernel_patches"
KERNEL_PATCH="$SUSFS_PATCHES/50_add_susfs_in_gki-android14-6.1.patch"

if [ ! -f "$KERNEL_PATCH" ]; then
    echo "[patch] ERROR: $KERNEL_PATCH not found." >&2
    echo "[patch] Available patches in $SUSFS_PATCHES:" >&2
    ls "$SUSFS_PATCHES" >&2 || true
    exit 1
fi

# Detect already-applied patch (idempotent re-runs).
if grep -q "susfs" fs/Makefile 2>/dev/null && [ -f fs/susfs.c ]; then
    echo "[patch] SUSFS already applied to kernel tree, skipping"
else
    echo "[patch] applying $KERNEL_PATCH"
    cp "$KERNEL_PATCH" ./
    git apply --check "$(basename "$KERNEL_PATCH")"
    git apply "$(basename "$KERNEL_PATCH")"
fi

# ---- 3. Drop SUSFS sources into the kernel tree ----------------------------
# These files are referenced by the patch above.
for d in fs include/linux; do
    if [ -d "$SUSFS_PATCHES/$d" ]; then
        echo "[patch] copying $SUSFS_PATCHES/$d/ -> $d/"
        cp -r "$SUSFS_PATCHES/$d/." "$d/"
    fi
done

# ---- 4. KernelSU-Next SUSFS integration patch (if present) -----------------
# next-susfs branch already has SUSFS hooks; this is a safety net for variants
# that need a separate KSU-side patch.
KSU_PATCH="$SUSFS_PATCHES/KernelSU/10_enable_susfs_for_ksu.patch"
if [ -f "$KSU_PATCH" ] && [ -d KernelSU-Next ]; then
    if (cd KernelSU-Next && git apply --check "$KSU_PATCH" 2>/dev/null); then
        echo "[patch] applying KSU-side SUSFS patch"
        (cd KernelSU-Next && git apply "$KSU_PATCH")
    else
        echo "[patch] KSU-side SUSFS patch not applicable (likely already integrated in next-susfs branch)"
    fi
fi

echo "[patch] done."
