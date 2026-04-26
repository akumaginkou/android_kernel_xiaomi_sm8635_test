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
# We use the `next-susfs-a14-6.1-dev` branch (v1.1.1, KSU 12879) which
# pairs with susfs4ksu v1.5.x. This pairing is the proven working
# combination — the newer `legacy-susfs` branch still has unfinished
# SUSFS integration as of 2026-04 (calls undefined ksu_handle_vfs_fstat
# etc. that no public susfs variant provides).
#
# Manager APK to install on device: KSU-Next v1.1.1 release.
# Userspace SUSFS UI: sidex15/susfs4ksu-module (requires SUSFS 1.5.2+
# in kernel, our v1.5.12 satisfies this).
#
# Other valid setup.sh args (per official install guide):
#   stable  = v3.2.0 (no SUSFS at all)
#   legacy  = older non-GKI kernels
export KSU_NEXT_INSTALLER="${KSU_NEXT_INSTALLER:-https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh}"
export KSU_NEXT_TAG="${KSU_NEXT_TAG:-next-susfs-a14-6.1-dev}"

# SUSFS (simonpunk).
#   - branch matches kernel KMI: peridot lineage-23.2 = kernel 6.1 ->
#     `gki-android14-6.1` (Google GKI naming caps at android14 for 6.1).
#   - SUSFS_REF pins commit f16560c = "Bump version to v1.5.12; Synced
#     with KernelSU main branch ...". This is the last v1.5.x commit
#     before the v2.0 API rebase. v1.5.12 also satisfies sidex15/
#     susfs4ksu-module's "SUSFS 1.5.2 or later" requirement.
export SUSFS_REPO="${SUSFS_REPO:-https://gitlab.com/simonpunk/susfs4ksu.git}"
export SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android14-6.1}"
export SUSFS_REF="${SUSFS_REF:-f16560ce8263fbfa9b2f259e9531f72d6fda4e3f}"
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
