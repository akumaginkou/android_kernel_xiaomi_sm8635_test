#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

cd "$KERNEL_DIR"

# ---- Install ReSukiSU ------------------------------------------------------
# setup.sh clones ReSukiSU into KernelSU/, symlinks drivers/kernelsu, and
# patches drivers/Makefile + drivers/Kconfig to source it. SUSFS is part
# of ReSukiSU's own kernel/ tree (no external susfs4ksu patches needed).
#
# ReSukiSU has no tagged releases yet, so we pass `main` explicitly to
# avoid setup.sh's failing "checkout latest tag" branch.
if [ ! -d KernelSU ]; then
    echo "[patch] installing ReSukiSU ($RESUKISU_TAG)"
    curl -LSs "$RESUKISU_INSTALLER" | bash -s "$RESUKISU_TAG"
else
    echo "[patch] ReSukiSU already present, skipping installer"
fi

# Verify the requested ref was actually checked out (setup.sh silently
# falls back to the default branch on a bad ref).
ACTUAL_REF="$(git -C KernelSU rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
if [ "$ACTUAL_REF" = "HEAD" ]; then
    ACTUAL_REF="$(git -C KernelSU rev-parse --short HEAD)"
fi
echo "[patch] ReSukiSU on $ACTUAL_REF"

# Sanity: SUSFS Kconfig must be visible (otherwise the fragment merge
# would silently drop CONFIG_KSU_SUSFS=y and we'd ship a SUSFS-less
# kernel without noticing).
if ! grep -q "config KSU_SUSFS" KernelSU/kernel/Kconfig 2>/dev/null; then
    echo "[patch] ERROR: KSU_SUSFS Kconfig not found in ReSukiSU/kernel/Kconfig" >&2
    exit 1
fi
echo "[patch] SUSFS Kconfig present (built into ReSukiSU)"

echo "[patch] done."
