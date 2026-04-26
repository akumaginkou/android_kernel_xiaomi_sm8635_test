### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
##
## peridot (Xiaomi POCO F6 / Redmi Turbo 3, SM8635) — Android 16 / GKI 6.1
## Settings here are aligned with the established peridot kernel community
## conventions (GuidixX, Lu5ck, farrukh2002, ...) — diverging from these
## causes "Repacking image failed" / "Busybox setup failed" on this device.

### Properties
# do.cleanuponabort=0 keeps /tmp/anykernel/ around if flash aborts so
# we can `adb shell cat /tmp/recovery.log` and see the real failure.
properties() { '
kernel.string=peridot kernel (ReSukiSU + SUSFS) by akumaginkou
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=peridot
device.name2=Peridot
device.name3=Xiaomi POCO F6
device.name4=Redmi Turbo 3
supported.versions=14 - 16
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### Boot shell variables
# Use bare partition name (let AK3 find the right /dev/block/by-name path);
# auto-detect A/B vs A-only; disable AK3's magisk detection branch which
# misfires on init_boot devices whose boot.img has an empty ramdisk.
block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=1

# shell variables
. tools/ak3-core.sh

### Boot install
# Standard peridot pattern (GuidixX/Lu5ck/farrukh2002 etc.): use
# split_boot + flash_boot regardless of init_boot, because boot.img
# on this device still has a (minimal) ramdisk that magiskboot needs
# to round-trip through. Earlier attempts to use dump_boot/write_boot
# died with "No ramdisk found to unpack".
if [ -L "/dev/block/bootdevice/by-name/init_boot_a" -o -L "/dev/block/by-name/init_boot_a" -o \
     -L "/dev/block/bootdevice/by-name/init_boot"   -o -L "/dev/block/by-name/init_boot"   ]; then
    ui_print " " "init_boot detected — kernel goes into boot partition only"
fi
split_boot
flash_boot
## end boot install
