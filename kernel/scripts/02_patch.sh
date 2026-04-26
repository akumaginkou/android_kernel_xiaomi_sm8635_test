#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

cd "$KERNEL_DIR"

# ---- 1. Install KernelSU-Next ----------------------------------------------
# The official setup.sh adds drivers/kernelsu (symlink) and patches
# drivers/Makefile + drivers/Kconfig. KSU_NEXT_TAG must be a real ref;
# setup.sh silently falls back to default branch on a bad ref, so we
# verify after.
if [ ! -d KernelSU-Next ]; then
    echo "[patch] installing KernelSU-Next ($KSU_NEXT_TAG)"
    curl -LSs "$KSU_NEXT_INSTALLER" | bash -s "$KSU_NEXT_TAG"
else
    echo "[patch] KernelSU-Next already present, skipping installer"
fi

ACTUAL_BRANCH="$(git -C KernelSU-Next rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
if [ "$ACTUAL_BRANCH" != "$KSU_NEXT_TAG" ]; then
    echo "[patch] ERROR: KernelSU-Next is on '$ACTUAL_BRANCH', expected '$KSU_NEXT_TAG'." >&2
    echo "[patch] setup.sh silently fell back. Verify '$KSU_NEXT_TAG' exists upstream." >&2
    exit 1
fi
echo "[patch] KernelSU-Next on branch $ACTUAL_BRANCH"

# ---- 2. Apply SUSFS kernel-side patch + source overlay ---------------------
# KSU-Next's legacy-susfs branch only contains the KSU side of the SUSFS
# integration; the actual implementation (linux/susfs.h, fs/susfs.c,
# hook patches into fs/exec.c etc.) ships with simonpunk/susfs4ksu.
# Without this step the build dies with: linux/susfs.h: file not found.
SUSFS_PATCHES="$SUSFS_DIR/kernel_patches"
KERNEL_PATCH="$SUSFS_PATCHES/50_add_susfs_in_gki-android14-6.1.patch"

if [ ! -f "$KERNEL_PATCH" ]; then
    echo "[patch] ERROR: $KERNEL_PATCH not found." >&2
    echo "[patch] Available patches in $SUSFS_PATCHES:" >&2
    ls "$SUSFS_PATCHES" 2>/dev/null >&2 || true
    exit 1
fi

# Idempotent: skip if already applied.
if grep -q "susfs" fs/Makefile 2>/dev/null && [ -f fs/susfs.c ]; then
    echo "[patch] SUSFS kernel patch already applied, skipping"
else
    echo "[patch] applying $KERNEL_PATCH"
    cp "$KERNEL_PATCH" ./
    git apply --check "$(basename "$KERNEL_PATCH")"
    git apply "$(basename "$KERNEL_PATCH")"
fi

# Drop SUSFS implementation files into the kernel tree.
for d in fs include/linux; do
    if [ -d "$SUSFS_PATCHES/$d" ]; then
        echo "[patch] copying $SUSFS_PATCHES/$d/ -> $d/"
        cp -r "$SUSFS_PATCHES/$d/." "$d/"
    fi
done

# Sanity: the header KSU-Next will include must now exist.
if [ ! -f include/linux/susfs.h ]; then
    echo "[patch] ERROR: include/linux/susfs.h missing after SUSFS overlay." >&2
    exit 1
fi

echo "[patch] SUSFS_VERSION in tree: $(grep '^#define SUSFS_VERSION' include/linux/susfs.h | awk '{print $3}')"

# ---- 3. KSU-Next-side SUSFS patch (only if needed) -------------------------
# v3.x legacy-susfs already integrates the KSU side; the simonpunk patch
# would conflict. We only apply it if a dry-run succeeds.
KSU_PATCH="$SUSFS_PATCHES/KernelSU/10_enable_susfs_for_ksu.patch"
if [ -f "$KSU_PATCH" ] && [ -d KernelSU-Next ]; then
    if (cd KernelSU-Next && git apply --check "$KSU_PATCH" 2>/dev/null); then
        echo "[patch] applying KSU-side SUSFS patch"
        (cd KernelSU-Next && git apply "$KSU_PATCH")
    else
        echo "[patch] KSU-side SUSFS patch not applicable (already integrated in legacy-susfs)"
    fi
fi

# ---- 4. Hotfix: missing sepolicy declarations in legacy-susfs HEAD ---------
# The "Add SUSFS support (#1237)" commit (4cc162e, 2026-04-23) on the
# legacy-susfs branch introduced calls to ksu_dup_sepolicy() and
# ksu_destroy_sepolicy() in selinux/rules.c, but forgot to add their
# prototypes to selinux/sepolicy.h. Build dies with:
#   error: call to undeclared function 'ksu_dup_sepolicy'
#   error: call to undeclared function 'ksu_destroy_sepolicy'
# Inject the prototypes ourselves until upstream fixes it.
SEPOL_H="KernelSU-Next/kernel/selinux/sepolicy.h"
if [ -f "$SEPOL_H" ] && ! grep -q "ksu_dup_sepolicy" "$SEPOL_H"; then
    echo "[patch] hotfix: declaring ksu_dup_sepolicy / ksu_destroy_sepolicy in sepolicy.h"
    sed -i 's|^#endif$|struct selinux_policy;\nstruct selinux_policy *ksu_dup_sepolicy(struct selinux_policy *old_pol);\nvoid ksu_destroy_sepolicy(struct selinux_policy *pol);\n\n#endif|' "$SEPOL_H"
fi

echo "[patch] done."
