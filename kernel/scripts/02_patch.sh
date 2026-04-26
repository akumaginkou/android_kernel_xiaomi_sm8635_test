#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

cd "$KERNEL_DIR"

# ---- Install KernelSU-Next -------------------------------------------------
# The official setup.sh (per https://kernelsu-next.github.io/webpage/pages/installation.html):
#   curl -LSs <setup.sh> | bash -s <branch-or-tag>
# adds drivers/kernelsu (symlink to KernelSU-Next/kernel/) and patches
# drivers/Makefile + drivers/Kconfig.
#
# KSU_NEXT_TAG must be a real branch/tag in KSU-Next. setup.sh silently
# falls back to the default branch when the requested ref does not exist
# (`git checkout "$1" || echo`); we verify below to fail loudly.
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

# Sanity: the legacy-susfs branch should expose SUSFS Kconfig options.
if [ "$KSU_NEXT_TAG" = "legacy-susfs" ] || [[ "$KSU_NEXT_TAG" == *susfs* ]]; then
    if ! grep -q "config KSU_SUSFS" KernelSU-Next/kernel/Kconfig 2>/dev/null; then
        echo "[patch] ERROR: expected SUSFS Kconfig options not found in KernelSU-Next/kernel/Kconfig" >&2
        exit 1
    fi
    echo "[patch] SUSFS Kconfig present (built into KernelSU-Next, no external patches needed)"
fi

echo "[patch] done."
