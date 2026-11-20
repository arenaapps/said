#!/bin/bash
# Builds a Said.app that runs on both Intel and Apple silicon Macs, and zips it
# into build/Said-<version>.zip for a GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
REL=vendor/release

for ARCH in x86_64 arm64; do
  [ -f "$REL/$ARCH/lib/libwhisper.a" ] || SAID_ARCH=$ARCH SAID_PORTABLE=1 SAID_WHISPER_DIR="$REL/$ARCH" ./scripts/build-whisper.sh
done

# One library file per name holding both architectures.
rm -rf "$REL/universal"
mkdir -p "$REL/universal/lib"
cp -R "$REL/arm64/include" "$REL/universal/include"
for LIB in "$REL"/arm64/lib/*.a; do
  NAME="$(basename "$LIB")"
  lipo -create "$LIB" "$REL/x86_64/lib/$NAME" -output "$REL/universal/lib/$NAME"
done

SAID_UNSIGNED=1 SAID_WHISPER_DIR="$REL/universal" SAID_SWIFT_ARCHS="--arch arm64 --arch x86_64" ./scripts/bundle.sh release
lipo -info build/Said.app/Contents/MacOS/Said

ZIP="build/Said-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/Said.app "$ZIP"
echo "Wrote $ZIP"
