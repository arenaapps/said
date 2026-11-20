#!/bin/bash
# Builds whisper.cpp as static libraries into ./vendor/whisper (gitignored),
# which Package.swift links against. Run once before the first build.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=v1.9.5
SRC=vendor/whisper.cpp
OUT="$PWD/vendor/whisper"
CMAKE="$(command -v cmake || echo "$HOME/.local/cmake-3.31.6-macos-universal/CMake.app/Contents/bin/cmake")"
[ -d "$SRC" ] || git clone -q --depth 1 --branch "$VERSION" https://github.com/ggml-org/whisper.cpp "$SRC"
ARCHS="${SAID_ARCHS:-$(uname -m)}"  # set SAID_NATIVE=OFF for builds that run on other Macs
"$CMAKE" -S "$SRC" -B "$SRC/build-static" \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_OSX_ARCHITECTURES="$ARCHS" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DWHISPER_BUILD_SERVER=OFF \
  -DGGML_NATIVE="${SAID_NATIVE:-ON}" -DGGML_METAL_EMBED_LIBRARY=ON \
  -DCMAKE_INSTALL_PREFIX="$OUT" > /dev/null
"$CMAKE" --build "$SRC/build-static" -j "$(sysctl -n hw.ncpu)" > /dev/null
"$CMAKE" --install "$SRC/build-static" > /dev/null
echo "whisper.cpp $VERSION installed to $OUT"
ls "$OUT/lib"/*.a
