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

# ReSukiSU (KernelSU-based root + SUSFS, all integrated).
# Replaces the previous KSU-Next + susfs4ksu split. ReSukiSU bundles
# the SUSFS implementation directly in drivers/kernelsu/, so no
# external susfs4ksu kernel patches or fs/susfs.c overlay are needed.
# The Manager APK ships userspace SUSFS binaries (ksu_susfs_2.0.0 /
# ksu_susfs_2.1.0) so no separate sidex15/BRENE module is required.
#
# ReSukiSU has no tagged releases yet (rolling); setup.sh's no-arg
# "checkout latest tag" path would fail, so we pass `main` explicitly.
export RESUKISU_INSTALLER="${RESUKISU_INSTALLER:-https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh}"
export RESUKISU_TAG="${RESUKISU_TAG:-main}"

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
export KERNEL_NAME="${KERNEL_NAME:-PeridotReSukiSU}"
export ZIP_NAME="${ZIP_NAME:-${KERNEL_NAME}-$(date -u +%Y%m%d-%H%M)-AnyKernel3.zip}"

mkdir -p "$WORKDIR" "$OUTDIR" "$CCACHE_DIR"

echo "[env] PROJECT_ROOT  = $PROJECT_ROOT"
echo "[env] WORKDIR       = $WORKDIR"
echo "[env] KERNEL_REPO   = $KERNEL_REPO ($KERNEL_BRANCH)"
echo "[env] RESUKISU_TAG  = $RESUKISU_TAG"
