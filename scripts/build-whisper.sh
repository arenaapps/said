#!/bin/bash
# Builds whisper.cpp as static libraries, which Package.swift links against.
#
#   ./scripts/build-whisper.sh                 this Mac only, tuned to its processor, into vendor/whisper
#   SAID_ARCH=arm64 SAID_PORTABLE=1 SAID_WHISPER_DIR=vendor/release/arm64 ./scripts/build-whisper.sh
#                                              one architecture that runs on any Mac of that kind (for releases)
set -euo pipefail
# -ffile-prefix-map keeps the builder's folder (and so their user name) out of the library.
cd "$(dirname "$0")/.."
VERSION=v1.9.5
SRC=vendor/whisper.cpp
ARCH="${SAID_ARCH:-$(uname -m)}"
OUT="$PWD/${SAID_WHISPER_DIR:-vendor/whisper}"
CMAKE="$(command -v cmake || echo "$HOME/.local/cmake-3.31.6-macos-universal/CMake.app/Contents/bin/cmake")"
[ -d "$SRC" ] || git clone -q --depth 1 --branch "$VERSION" https://github.com/ggml-org/whisper.cpp "$SRC"

if [ -n "${SAID_PORTABLE:-}" ]; then
  BUILD="$SRC/build-$ARCH-portable"
  CPU=(-DGGML_NATIVE=OFF)
  # Every Intel Mac that runs macOS 14 has AVX2, FMA and F16C. Apple silicon
  # gets the M1 feature set from the compiler's arm64 default.
  [ "$ARCH" = x86_64 ] && CPU+=(-DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON)
else
  BUILD="$SRC/build-static"
  CPU=(-DGGML_NATIVE=ON)
fi

"$CMAKE" -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF \
  "${CPU[@]}" -DGGML_METAL_EMBED_LIBRARY=ON \
  -DCMAKE_C_FLAGS="-ffile-prefix-map=$PWD/=" -DCMAKE_CXX_FLAGS="-ffile-prefix-map=$PWD/=" \
  -DCMAKE_OBJC_FLAGS="-ffile-prefix-map=$PWD/=" -DCMAKE_OBJCXX_FLAGS="-ffile-prefix-map=$PWD/=" \
  -DCMAKE_INSTALL_PREFIX="$OUT" > /dev/null
"$CMAKE" --build "$BUILD" -j "$(sysctl -n hw.ncpu)" > /dev/null
"$CMAKE" --install "$BUILD" > /dev/null
echo "whisper.cpp $VERSION ($ARCH) installed to $OUT"
