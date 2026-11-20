#!/bin/bash
# Builds Said.app into ./build and signs it with a stable identity so macOS
# keeps the Microphone, Input Monitoring and Accessibility permissions between rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
[ -f vendor/whisper/lib/libwhisper.a ] || ./scripts/build-whisper.sh
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Said"
APP=build/Said.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Said"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Put SAID_SIGN_IDENTITY=<certificate hash or name> in scripts/sign.local (gitignored)
# or the environment. Without one the app is signed ad hoc, and macOS asks for
# permissions again after each rebuild.
[ -f scripts/sign.local ] && source scripts/sign.local
IDENTITY="${SAID_SIGN_IDENTITY:--}"
codesign --force --sign "$IDENTITY" --entitlements Resources/Said.entitlements "$APP" 2>/dev/null \
  || codesign --force --sign - --entitlements Resources/Said.entitlements "$APP"
echo "Built $APP"
