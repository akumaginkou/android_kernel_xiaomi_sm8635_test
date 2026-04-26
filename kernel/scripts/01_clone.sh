#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/00_env.sh"

clone_or_update() {
    local repo="$1" branch="$2" dest="$3"
    if [ -d "$dest/.git" ]; then
        echo "[clone] $dest exists; fetching latest $branch"
        git -C "$dest" fetch --depth=1 origin "$branch"
        git -C "$dest" checkout -f "FETCH_HEAD"
    else
        echo "[clone] $repo -> $dest ($branch)"
        git clone --depth=1 --branch "$branch" "$repo" "$dest"
    fi
}

clone_or_update "$KERNEL_REPO"    "$KERNEL_BRANCH"    "$KERNEL_DIR"
clone_or_update "$ANYKERNEL_REPO" "$ANYKERNEL_BRANCH" "$ANYKERNEL_DIR"

# susfs needs a specific commit (API breakage between v1.5.x / v2.x), so
# do a full clone and then check out the pinned ref.
if [ -d "$SUSFS_DIR/.git" ]; then
    echo "[clone] $SUSFS_DIR exists; fetching"
    git -C "$SUSFS_DIR" fetch origin "$SUSFS_BRANCH"
else
    echo "[clone] $SUSFS_REPO -> $SUSFS_DIR ($SUSFS_BRANCH, full)"
    git clone --branch "$SUSFS_BRANCH" "$SUSFS_REPO" "$SUSFS_DIR"
fi

if [ -n "${SUSFS_REF:-}" ]; then
    echo "[clone] pinning susfs to $SUSFS_REF"
    git -C "$SUSFS_DIR" checkout -f "$SUSFS_REF"
fi

ACTUAL_VER="$(grep '^#define SUSFS_VERSION' "$SUSFS_DIR/kernel_patches/include/linux/susfs.h" 2>/dev/null | awk '{print $3}' | tr -d '"' || echo unknown)"
echo "[clone] susfs version: $ACTUAL_VER"

echo "[clone] done."
