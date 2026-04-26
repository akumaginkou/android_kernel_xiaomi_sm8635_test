# android_kernel_xiaomi_sm8635_test

Custom kernel build for **Xiaomi POCO F6 / Redmi Turbo 3** (codename `peridot`,
SoC SM8635 / Snapdragon 8s Gen 3), with **ReSukiSU** (KernelSU-based root +
SUSFS, all bundled) and a few QoL kernel features, packaged as an **AnyKernel3**
flashable zip.

Targets AOSP-based custom ROMs on **Android 16** (crDroid 12.x, EvolutionX 11.x,
LineageOS 23.x, ...).

> ⚠️ **Disclaimer / 免責事項**
>
> - This is a **personal hobby project** maintained by a single individual.
>   No warranty, no support SLA, no guarantee that any build boots, works
>   correctly, or doesn't brick your device. **Use at your own risk.**
> - This repository was **bootstrapped and iterated with the help of an
>   AI assistant** (Claude). All scripts, defconfig fragments, build
>   workflows, and this README were drafted by AI under human review and
>   may contain mistakes. Always read the diffs before flashing.
> - Flashing custom kernels can result in boot loops, data loss, hardware
>   damage, voided warranties, and tripped attestation. Have a recovery
>   path (working ROM image, fastboot access, the original `boot.img` to
>   restore) before you flash anything from here.
> - 本リポジトリは**個人の趣味プロジェクト**です。動作保証・サポートは一切ありません。
>   AI (Claude) を補助として実装しており、誤りが含まれる可能性があります。
>   フラッシュ前に必ず差分とログを確認し、復旧手段を確保したうえで
>   **自己責任**でご利用ください。

## Components

| Layer | Source | Notes |
|---|---|---|
| Kernel | [peridot-dev/android_kernel_xiaomi_sm8635](https://github.com/peridot-dev/android_kernel_xiaomi_sm8635) `lineage-23.2` | kernel 6.1, AOSP-style fork |
| Root + SUSFS | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) `main` | KernelSU fork with SUSFS bundled, KPM support, multi-manager |
| Pack  | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) `master` | flashable zip wrapper |

> **Why ReSukiSU?** Earlier iterations of this repo tried KernelSU-Next
> + simonpunk/susfs4ksu in various pairings; all hit version-mismatch or
> missing-symbol issues because the KSU-Next ↔ susfs4ksu APIs have
> diverged. ReSukiSU integrates SUSFS directly into the KSU driver tree
> (no external patches), ships the userspace `ksu_susfs` binary inside
> its Manager APK (no separate sidex15/BRENE module needed), and keeps
> the standard `CONFIG_KSU_SUSFS_*` Kconfig surface so the build stays
> simple. It is a fork of SukiSU-Ultra focused on stability and broad
> kernel-version support (Linux 3.4 – 6.12).

## Extra kernel features

Configured via [`kernel/config/extras.fragment`](kernel/config/extras.fragment).
Independent of root — delete the file to drop them.

| Feature | What it gives you |
|---|---|
| **WireGuard** | Native in-kernel VPN. tailscale, Mullvad, etc. run faster than via userspace. |
| **TCP BBR + FQ qdisc** | Better throughput on high-RTT / lossy links. v1 only — v3 needs ~50 backport patches. |
| **NTFS3** | In-kernel NTFS read/write, replaces FUSE-based ntfs-3g. |
| **exFAT improvements** | Force built-in (no first-mount delay), default I/O charset = UTF-8, codepages 437 / 932 (Shift_JIS) preloaded so Windows-formatted SD cards round-trip Japanese filenames correctly. |

## Repository layout

```
.
├── .github/workflows/build-kernel.yml   GitHub Actions build (ubuntu-24.04)
├── Dockerfile.kernel                    Local build env (Ubuntu 24.04 + clang-18)
├── docker-compose.yml                   `kernel-builder` service
├── kernel/
│   ├── scripts/
│   │   ├── 00_env.sh                    Shared env vars (override via env)
│   │   ├── 01_clone.sh                  Clone kernel + AnyKernel3
│   │   ├── 02_patch.sh                  Install ReSukiSU (KSU+SUSFS)
│   │   ├── 03_build.sh                  defconfig + clang build
│   │   └── 04_pack.sh                   Package Image into AnyKernel3 zip
│   ├── config/
│   │   ├── ksu_susfs.fragment           CONFIG_KSU=y, CONFIG_KSU_SUSFS=y, ...
│   │   └── extras.fragment              WireGuard, BBR, NTFS3, exFAT (UTF-8/JIS)
│   └── anykernel/
│       └── anykernel.sh                 peridot-tuned AK3 install script
├── out/                                 Build artefacts (.zip)  [gitignored]
└── work/                                Cloned sources, build tree [gitignored]
```

## Build via GitHub Actions (recommended)

1. Push this repo to GitHub.
2. Open **Actions → Build peridot kernel (ReSukiSU + SUSFS) → Run workflow**.
3. (Optional) Override `kernel_branch` or `resukisu_tag`.
4. The flashable zip appears under **Artifacts** as
   `PeridotReSukiSU-AnyKernel3-<run>.zip`.

To attach the zip to a GitHub Release, run with `release=true` and set
`release_tag` (e.g. `v0.1`).

The workflow also runs automatically on pushes that touch `kernel/**`,
`Dockerfile.kernel`, or the workflow file itself.

## Build locally with Docker

```bash
docker compose build kernel-builder
docker compose run --rm kernel-builder

# Inside the container:
bash kernel/scripts/01_clone.sh
bash kernel/scripts/02_patch.sh
bash kernel/scripts/03_build.sh
bash kernel/scripts/04_pack.sh
# -> out/PeridotReSukiSU-<timestamp>-AnyKernel3.zip
```

ccache is persisted in the `kernel_ccache` named volume; second runs are
much faster.

## Build locally without Docker (Linux host)

Install: `bc bison build-essential ccache curl flex git libelf-dev libssl-dev
cpio rsync zip clang lld llvm dwarves` (Ubuntu 24.04 ships clang-18 which works
for kernel 6.1).

```bash
bash kernel/scripts/01_clone.sh
bash kernel/scripts/02_patch.sh
bash kernel/scripts/03_build.sh
bash kernel/scripts/04_pack.sh
```

## Flashing

1. Boot to a recovery that can flash zips (TWRP, OrangeFox, or a custom
   recovery with sideload support).
2. Sideload or flash `out/PeridotReSukiSU-*-AnyKernel3.zip`.
3. Reboot.
4. Install the **ReSukiSU Manager APK** from
   [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) — the
   manager has the SUSFS UI built in, no separate `sidex15/susfs4ksu-module`
   or `BRENE` module is required.
5. Verify: open the manager → it should show `KernelSU: working` and
   `SuSFS: <version>` (e.g. v2.1.0).

> ⚠️ The kernel KMI must match the ROM you're running. Branch
> `lineage-23.2` targets Android 16 GKI; flashing on an Android 15 ROM
> will boot-loop. For Android 15 ROMs use `lineage-22.2` (override
> `KERNEL_BRANCH` / `kernel_branch` accordingly).

## Customisation

Override env vars before invoking the scripts:

```bash
KERNEL_BRANCH=lineage-22.2 \
RESUKISU_TAG=main \
KERNEL_NAME=MyPeridot \
bash kernel/scripts/03_build.sh
```

Add or remove kernel features by editing
`kernel/config/ksu_susfs.fragment` or `kernel/config/extras.fragment`.
03_build.sh globs every `kernel/config/*.fragment`, so dropping a new
file there is enough — no script edits needed.

## Status

This is a **test repository** in active iteration. Earlier commit history
documents the dead ends (KSU-Next + susfs version mismatches, the
legacy-susfs branch's incomplete integration, etc.) — the current
ReSukiSU setup is the result of that learning. Verify on your own device,
expect breakage, file issues with full `dmesg` output and the exact ROM
build you flashed onto.
