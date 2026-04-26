# android_kernel_xiaomi_sm8635_test

Custom kernel build for **Xiaomi POCO F6 / Redmi Turbo 3** (codename `peridot`,
SoC SM8635 / Snapdragon 8s Gen 3), with **KernelSU-Next** and **SUSFS**
integrated, packaged as an **AnyKernel3** flashable zip.

Targets AOSP-based custom ROMs on **Android 16** (crDroid 12.x, EvolutionX 11.x,
LineageOS 23.x, ...).

## Components

| Layer | Source | Branch / tag |
|---|---|---|
| Kernel | [peridot-dev/android_kernel_xiaomi_sm8635](https://github.com/peridot-dev/android_kernel_xiaomi_sm8635) | `lineage-23.2` (kernel 6.1, android15-6.1 GKI) |
| Root  | [KernelSU-Next/KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) | `next-susfs` |
| Hide  | [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) | `gki-android14-6.1` |
| Pack  | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) | `master` |

## Repository layout

```
.
├── .github/workflows/build-kernel.yml   GitHub Actions build (ubuntu-24.04)
├── Dockerfile.kernel                    Local build env (Ubuntu 24.04 + clang-18)
├── docker-compose.yml                   `kernel-builder` service
├── kernel/
│   ├── scripts/
│   │   ├── 00_env.sh                    Shared env vars (override via env)
│   │   ├── 01_clone.sh                  Clone kernel + KSU-Next + SUSFS + AK3
│   │   ├── 02_patch.sh                  Apply KSU-Next + SUSFS patches
│   │   ├── 03_build.sh                  defconfig + clang build
│   │   └── 04_pack.sh                   Package Image into AnyKernel3 zip
│   ├── config/
│   │   └── ksu_susfs.fragment           CONFIG_KSU=y, CONFIG_KSU_SUSFS=y, ...
│   └── anykernel/
│       └── anykernel.sh                 peridot-tuned AK3 install script
├── out/                                 Build artefacts (.zip)  [gitignored]
└── work/                                Cloned sources, build tree [gitignored]
```

## Build via GitHub Actions (recommended)

1. Push this repo to GitHub (e.g. `akumaginkou/android_kernel_xiaomi_sm8635_test`).
2. Open **Actions → Build peridot kernel → Run workflow**.
3. (Optional) Override `kernel_branch`, `ksu_next_tag`, `susfs_branch`.
4. The flashable zip appears under **Artifacts** as
   `PeridotKSU-AnyKernel3-<run>.zip`.

To attach the zip to a GitHub Release, run with `release=true` and set
`release_tag` (e.g. `v0.1`).

The workflow also runs automatically on pushes that touch `kernel/**`,
`Dockerfile.kernel`, or the workflow file itself.

## Build locally with Docker

```bash
# Build the image (~1.5 GB).
docker compose build kernel-builder

# Drop into the container.
docker compose run --rm kernel-builder

# Inside the container:
bash kernel/scripts/01_clone.sh
bash kernel/scripts/02_patch.sh
bash kernel/scripts/03_build.sh
bash kernel/scripts/04_pack.sh
# -> out/PeridotKSU-<timestamp>-AnyKernel3.zip
```

ccache is persisted in the `kernel_ccache` named volume; second runs are much
faster.

## Build locally without Docker (Linux host)

Install: `bc bison build-essential ccache curl flex git libelf-dev libssl-dev
cpio rsync zip clang lld llvm` (Ubuntu 24.04 ships clang-18 which works for
android15-6.1).

```bash
bash kernel/scripts/01_clone.sh
bash kernel/scripts/02_patch.sh
bash kernel/scripts/03_build.sh
bash kernel/scripts/04_pack.sh
```

## Flashing

1. Boot to recovery (TWRP, OrangeFox, or `adb reboot recovery` with a recovery
   that can flash zips).
2. Sideload or flash `out/PeridotKSU-*-AnyKernel3.zip`.
3. Reboot. Install the [KernelSU-Next manager APK](https://github.com/KernelSU-Next/KernelSU-Next/releases)
   to verify.

> ⚠️ The kernel KMI must match the ROM you are running. Branch `lineage-23.2`
> targets Android 16 GKI; flashing it on an Android 15 ROM will boot-loop.
> For Android 15 ROMs use `lineage-22.2` (override `KERNEL_BRANCH` /
> `kernel_branch` accordingly — and adjust `SUSFS_BRANCH` to match).

## Customisation

All inputs are env-driven. To bend the build, override before invoking the
scripts:

```bash
KERNEL_BRANCH=lineage-22.2 \
SUSFS_BRANCH=gki-android14-6.1 \
KERNEL_NAME=MyPeridot \
bash kernel/scripts/03_build.sh
```

Add or remove kernel features by editing `kernel/config/ksu_susfs.fragment`.

## Status

This is a **test repo** — verify on your own device, expect breakage, file
issues with full `dmesg` and the exact ROM build you flashed onto.
