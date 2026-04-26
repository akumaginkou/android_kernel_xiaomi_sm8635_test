#!/usr/bin/env bash
# Shared environment for kernel build scripts.
# Sourced by 01_clone.sh / 02_patch.sh / 03_build.sh / 04_pack.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# ReSukiSU (KernelSU-based root + KPM, modern fork of SukiSU-Ultra).
# Provides the KSU-side ksu_handle_* implementations (in drivers/kernelsu/
# hook/setuid_hook.c, syscall_hook_manager.c, etc.). The kernel-side
# inline hook calls + linux/susfs.h come from susfs4ksu (see below).
# ReSukiSU is rolling — no tags — so we pin to `main`.
export RESUKISU_INSTALLER="${RESUKISU_INSTALLER:-https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh}"
export RESUKISU_TAG="${RESUKISU_TAG:-main}"

# SUSFS (simonpunk). HEAD of gki-android14-6.1 = v2.1.0, which adds ALL
# seven ksu_handle_* inline hooks ReSukiSU's inline_hook_check.mk
# requires:
#   ksu_handle_setresuid          (kernel/sys.c)
#   ksu_handle_execveat           (fs/exec.c)
#   ksu_handle_faccessat          (fs/open.c)
#   ksu_handle_sys_read           (fs/read_write.c)
#   ksu_handle_stat               (fs/stat.c)
#   ksu_handle_sys_reboot         (kernel/reboot.c)
#   ksu_handle_input_handle_event (drivers/input/input.c)
# ReSukiSU implements all of these on the KSU side, so the symbols
# resolve at link time without any additional patches.
export SUSFS_REPO="${SUSFS_REPO:-https://gitlab.com/simonpunk/susfs4ksu.git}"
export SUSFS_BRANCH="${SUSFS_BRANCH:-gki-android14-6.1}"
export SUSFS_REF="${SUSFS_REF:-}"   # empty = HEAD of branch
export SUSFS_DIR="${SUSFS_DIR:-$WORKDIR/susfs4ksu}"

# Build target
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-peridot-ci}"

export DEFCONFIG="${DEFCONFIG:-gki_defconfig}"
export VENDOR_DEFCONFIG="${VENDOR_DEFCONFIG:-vendor/peridot_GKI.config}"

# Toolchain.
# peridot's stock kernel banner advertises:
#   Android (... +pgo, +bolt, +lto, +mlgo, based on r563880c) clang 21.0.0
# Building with Ubuntu 24.04 system clang-18 produces an Image that
# boot-loops on real hardware (verified with the PURE / no-KSU rebuild
# also failing — the regression is in our toolchain, not in KSU/SUSFS).
# Use an AOSP clang prebuilt close to stock. r530567b is a known-good
# version widely used by the kernel community for android14-6.1 builds.
export AOSP_CLANG_VERSION="${AOSP_CLANG_VERSION:-r530567b}"
export CLANG_DIR="${CLANG_DIR:-$WORKDIR/aosp-clang/clang-$AOSP_CLANG_VERSION}"
export CC="${CC:-clang}"
export LLVM=1
export LLVM_IAS=1

export USE_CCACHE="${USE_CCACHE:-1}"
export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"

export KERNEL_NAME="${KERNEL_NAME:-PeridotReSukiSU}"
export ZIP_NAME="${ZIP_NAME:-${KERNEL_NAME}-$(date -u +%Y%m%d-%H%M)-AnyKernel3.zip}"

mkdir -p "$WORKDIR" "$OUTDIR" "$CCACHE_DIR"

echo "[env] PROJECT_ROOT  = $PROJECT_ROOT"
echo "[env] WORKDIR       = $WORKDIR"
echo "[env] KERNEL_REPO   = $KERNEL_REPO ($KERNEL_BRANCH)"
echo "[env] RESUKISU_TAG  = $RESUKISU_TAG"
echo "[env] SUSFS_BRANCH  = $SUSFS_BRANCH${SUSFS_REF:+ @ $SUSFS_REF}"
