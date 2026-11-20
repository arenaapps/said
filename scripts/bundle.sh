#!/bin/bash
# Builds Said.app into ./build and signs it with a stable identity so macOS
# keeps the Microphone, Input Monitoring and Accessibility permissions between rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
[ -f "${SAID_WHISPER_DIR:-vendor/whisper}/lib/libwhisper.a" ] || ./scripts/build-whisper.sh
# SAID_SWIFT_ARCHS="--arch arm64 --arch x86_64" builds for both kinds of Mac (see release.sh).
ARCHS=(${SAID_SWIFT_ARCHS:-})
swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Said"
APP=build/Said.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Said"
# A public build drops its debug symbols, which hold the builder's folder paths.
[ -n "${SAID_UNSIGNED:-}" ] && strip -S -x "$APP/Contents/MacOS/Said"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Put SAID_SIGN_IDENTITY=<certificate hash or name> in scripts/sign.local (gitignored)
# or the environment. Without one the app is signed ad hoc, and macOS asks for
# permissions again after each rebuild.
# SAID_UNSIGNED=1 (release.sh) skips any certificate, so public downloads carry no personal or company name.
[ -z "${SAID_UNSIGNED:-}" ] && [ -f scripts/sign.local ] && source scripts/sign.local
IDENTITY="${SAID_SIGN_IDENTITY:--}"
codesign --force --sign "$IDENTITY" --entitlements Resources/Said.entitlements "$APP" 2>/dev/null \
  || codesign --force --sign - --entitlements Resources/Said.entitlements "$APP"
echo "Built $APP"
