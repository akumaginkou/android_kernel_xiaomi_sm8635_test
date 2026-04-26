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

echo "[clone] done. (susfs4ksu no longer cloned: ReSukiSU bundles SUSFS internally)"
