# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers
#
# Peridot (Xiaomi POCO F6 / Redmi Turbo 3 — SM8635) configuration.
# Targets AOSP-based custom ROMs (crDroid, EvolutionX, etc.) on Android 16 / GKI 6.1.

## AnyKernel setup
properties() { '
kernel.string=PeridotKSU (KernelSU-Next + SUSFS) by akumaginkou
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=peridot
device.name2=Peridot
device.name3=Xiaomi POCO F6
device.name4=Redmi Turbo 3
supported.versions=14,15,16
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

## AnyKernel install
block=/dev/block/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

# shell variables
. tools/ak3-core.sh;

## AnyKernel boot install
# peridot is GKI: replace the kernel image only, keep ramdisk and dtbo intact.
split_boot;
flash_boot;
## end install
