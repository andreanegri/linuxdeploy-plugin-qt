#! /bin/bash

set -e
set -x

if [ "$ARCH" == "" ]; then
    echo 'Error: $ARCH is not set'
    exit 1
fi

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" linuxdeploy-plugin-qt-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname $0)))
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

if [ "$ARCH" == "i386" ]; then
    EXTRA_CMAKE_ARGS=("-DCMAKE_TOOLCHAIN_FILE=$REPO_ROOT/cmake/toolchains/i386-linux-gnu.cmake" "-DUSE_SYSTEM_CIMG=OFF")
fi

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo "${EXTRA_CMAKE_ARGS[@]}"

make -j$(nproc)

make install DESTDIR=AppDir

export UPD_INFO="gh-releases-zsync|linuxdeploy|linuxdeploy-plugin-qt|continuous|linuxdeploy-plugin-qt-$ARCH.AppImage"

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-"$ARCH".AppImage
chmod +x linuxdeploy*.AppImage
./linuxdeploy-"$ARCH".AppImage --appdir AppDir \
    -d "$REPO_ROOT"/resources/linuxdeploy-plugin-qt.desktop \
    -i "$REPO_ROOT"/resources/linuxdeploy-plugin-qt.svg \
    -e $(which patchelf) \
    -e $(which strip) \
    --output appimage

mv linuxdeploy-plugin-qt-"$ARCH".AppImage "$OLD_CWD"/