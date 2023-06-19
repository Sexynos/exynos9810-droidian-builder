#!/bin/bash
set -xe

BUILD_DIR="$(dirname "$(realpath "$0")")"/builddir

TMP="$BUILD_DIR/tmp"
mkdir -p "$TMP"
TMPDOWN="$BUILD_DIR/downloads"
mkdir -p "$TMPDOWN"

HERE=$(pwd)
SCRIPT="$(dirname "$(realpath "$0")")"/build

cp deviceinfo "$BUILD_DIR/downloads"
cp mkbootimg.py "$BUILD_DIR/downloads"

mkdir -p "${TMP}/partitions"

source "${HERE}/deviceinfo"

cd "$TMPDOWN"
[ -d aarch64-linux-android-4.9 ] || git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b pie-gsi --depth 1
GCC_PATH="$TMPDOWN/aarch64-linux-android-4.9"

if $deviceinfo_kernel_clang_compile; then
    [ -d linux-x86 ] || git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 -b android10-gsi --depth 1
    CLANG_PATH="$TMPDOWN/linux-x86/clang-r353983c"
fi

if [ "$deviceinfo_arch" == "aarch64" ]; then
    [ -d arm-linux-androideabi-4.9 ] || git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b pie-gsi --depth 1
    GCC_ARM32_PATH="$TMPDOWN/arm-linux-androideabi-4.9"
fi

KERNEL_DIR="$(basename "${deviceinfo_kernel_source}")"
KERNEL_DIR="${KERNEL_DIR%.*}"
[ -d "$KERNEL_DIR" ] || git clone "$deviceinfo_kernel_source" -b $deviceinfo_kernel_source_branch --depth 1

if [ -n "$deviceinfo_kernel_apply_overlay" ] && $deviceinfo_kernel_apply_overlay; then
    [ -d libufdt ] || git clone https://android.googlesource.com/platform/system/libufdt -b pie-gsi --depth 1
    [ -d dtc ] || git clone https://android.googlesource.com/platform/external/dtc -b pie-gsi --depth 1
fi

cp "${HERE}/droidian-ramdisk" halium-boot-ramdisk.img

if [ -n "$deviceinfo_kernel_apply_overlay" ] && $deviceinfo_kernel_apply_overlay; then
    "$SCRIPT/build-ufdt-apply-overlay.sh" "${TMPDOWN}"
fi

if $deviceinfo_kernel_clang_compile; then
    CC=clang \
    CLANG_TRIPLE=${deviceinfo_arch}-linux-gnu- \
    PATH="$CLANG_PATH/bin:$GCC_PATH/bin:$GCC_ARM32_PATH/bin:${PATH}" \
    "$SCRIPT/build-kernel.sh" "${TMPDOWN}" "${TMP}/system"
else
    PATH="$GCC_PATH/bin:${PATH}" \
    "$SCRIPT/build-kernel.sh" "${TMPDOWN}" "${TMP}/system"
fi

"$SCRIPT/make-bootimage.sh" "${TMPDOWN}/KERNEL_OBJ" "${TMPDOWN}/halium-boot-ramdisk.img" "${TMP}/partitions/boot.img"

if [ -z "$BUILD_DIR" ]; then
    rm -r "${TMP}"
    rm -r "${TMPDOWN}"
fi

echo "done"
