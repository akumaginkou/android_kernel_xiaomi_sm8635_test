#!/usr/bin/env bash
# Shared environment for kernel build scripts.
# Sourced by 01_clone.sh / 02_patch.sh / 03_build.sh / 04_pack.sh.
# All variables are overridable via the environment (CI inputs, docker -e, etc.).

set -euo pipefail

# Resolve project root (parent of kernel/scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Workspace where everything is cloned/built.
export WORKDIR="${WORKDIR:-$PROJECT_ROOT/work}"
export OUTDIR="${OUTDIR:-$PROJECT_ROOT/out}"

# Kernel source: peridot-dev (AOSP-style fork, lineage-23.2 = Android 16 / kernel 6.1)
export KERNEL_REPO="${KERNEL_REPO:-https://github.com/peridot-dev/android_kernel_xiaomi_sm8635.git}"
export KERNEL_BRANCH="${KERNEL_BRANCH:-lineage-23.2}"
export KERNEL_DIR="${KERNEL_DIR:-$WORKDIR/kernel}"

# AnyKernel3 (osm0sis upstream)
export ANYKERNEL_REPO="${ANYKERNEL_REPO:-https://github.com/osm0sis/AnyKernel3.git}"
export ANYKERNEL_BRANCH="${ANYKERNEL_BRANCH:-master}"
export ANYKERNEL_DIR="${ANYKERNEL_DIR:-$WORKDIR/AnyKernel3}"

# KernelSU-Next.
# IMPORTANT: the branch arg passed to setup.sh must be a *real* branch name
# in the KSU-Next repo. Suffixed branches such as `next-susfs-a14-6.1-dev`
# are the SUSFS-aware variants matched to a specific kernel KMI. The bare
# name `next-susfs` looks plausible but does NOT exist; setup.sh silently
# falls back to the default branch (no SUSFS) when the checkout fails.
#   peridot lineage-23.2 = kernel 6.1 -> next-susfs-a14-6.1-dev
export KSU_NEXT_INSTALLER="${KSU_NEXT_INSTALLER:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"
export KSU_NEXT_TAG="${KSU_NEXT_TAG:-next-susfs-a14-6.1-dev}"

# SUSFS (simonpunk). Branch must match the kernel version, NOT the Android
# version. Google GKI naming convention is `gki-android<N>-<kver>` and the
# 6.1 kernel line tops out at `android14-6.1` upstream — peridot's
# lineage-23.2 is kernel 6.1.x (shipped by Xiaomi), so this is the match
# even when the ROM on top is Android 16.
export SUSFS_REPO="${SUSFS_REPO:-https://gitlab.com/simonpunk/susfs4ksu.git}"
export SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android14-6.1}"
export SUSFS_DIR="${SUSFS_DIR:-$WORKDIR/susfs4ksu}"

# Build target
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-peridot-ci}"

# Defconfig: GKI base + peridot vendor fragment.
export DEFCONFIG="${DEFCONFIG:-gki_defconfig}"
export VENDOR_DEFCONFIG="${VENDOR_DEFCONFIG:-vendor/peridot_GKI.config}"

# Toolchain. Default to system clang (Ubuntu 24.04 ships clang-18, sufficient for 6.1).
# To use AOSP prebuilt clang, set CLANG_DIR=/path/to/clang and prepend its bin to PATH.
export CC="${CC:-clang}"
export LLVM=1
export LLVM_IAS=1

# ccache (honored by both local Docker and GHA cache step).
export USE_CCACHE="${USE_CCACHE:-1}"
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"

# Output naming
export KERNEL_NAME="${KERNEL_NAME:-PeridotKSU}"
export ZIP_NAME="${ZIP_NAME:-${KERNEL_NAME}-$(date -u +%Y%m%d-%H%M)-AnyKernel3.zip}"

mkdir -p "$WORKDIR" "$OUTDIR" "$CCACHE_DIR"

echo "[env] PROJECT_ROOT = $PROJECT_ROOT"
echo "[env] WORKDIR      = $WORKDIR"
echo "[env] KERNEL_REPO  = $KERNEL_REPO ($KERNEL_BRANCH)"
echo "[env] KSU_NEXT_TAG = $KSU_NEXT_TAG"
echo "[env] SUSFS_BRANCH = $SUSFS_BRANCH"
