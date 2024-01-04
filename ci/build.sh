#! /bin/bash

set -e
set -x

if [ "$ARCH" == "" ]; then
    echo 'Error: $ARCH is not set'
    exit 1
fi

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /docker-ramdisk ]; then
    TEMP_BASE=/docker-ramdisk
else
    TEMP_BASE=/tmp
fi

BUILD_DIR="$(mktemp -d -p "$TEMP_BASE" linuxdeploy-plugin-qt-build-XXXXXX)"

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT="$(readlink -f "$(dirname "$(dirname "$0")")")"
OLD_CWD="$(readlink -f .)"

pushd "$BUILD_DIR"

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON -DSTATIC_BUILD=ON

make -j"$(nproc)"

ctest -V --no-tests=error

make install DESTDIR=AppDir

patchelf_path="$(which patchelf)"
strip_path="$(which strip)"

export UPD_INFO="gh-releases-zsync|linuxdeploy|linuxdeploy-plugin-qt|continuous|linuxdeploy-plugin-qt-$ARCH.AppImage"

wget "https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-$ARCH.AppImage"
# qemu is not happy about the AppImage type 2 magic bytes, so we need to "fix" that
dd if=/dev/zero bs=1 count=3 seek=8 conv=notrunc of=linuxdeploy-"$ARCH".AppImage
chmod +x linuxdeploy*.AppImage

export DEBUG=1

./linuxdeploy-"$ARCH".AppImage --appdir AppDir \
    -d "$REPO_ROOT"/resources/linuxdeploy-plugin-qt.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-qt.svg \
    -e "$patchelf_path" \
    -e "$strip_path" \
    -v0 \
    --output appimage

mv linuxdeploy-plugin-qt-"$ARCH".AppImage* "$OLD_CWD"/
