#!/bin/bash
# Builds a universal (Apple Silicon + Intel) Platter.app, zips it for download,
# installs it to /Applications and relaunches it. Usage: ./build.sh [--no-install]
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
APP=Platter
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
rm -rf build
mkdir -p build dist
for ARCH in arm64 x86_64; do
  echo "==> Compiling for $ARCH"
  TARGET="$ARCH-apple-macos13.0"
  clang -O2 -std=c11 -target "$TARGET" -c Sources/DriveSynth.c -o "build/DriveSynth-$ARCH.o"
  swiftc -O -swift-version 5 -target "$TARGET" \
    -import-objc-header Sources/DriveSynth.h \
    Sources/*.swift "build/DriveSynth-$ARCH.o" \
    -framework AppKit -framework SwiftUI -framework AVFoundation -framework IOKit -framework ServiceManagement \
    -module-cache-path "build/cache-$ARCH" \
    -o "build/$APP-$ARCH"
done
lipo -create "build/$APP-arm64" "build/$APP-x86_64" -output "build/$APP"
echo "==> Bundling"
B="build/$APP.app/Contents"
mkdir -p "$B/MacOS" "$B/Resources"
cp "build/$APP" "$B/MacOS/$APP"
cp Resources/Info.plist "$B/Info.plist"
cp Resources/AppIcon.icns "$B/Resources/AppIcon.icns"
codesign --force --deep --sign - "build/$APP.app"
lipo -info "$B/MacOS/$APP"
rm -f "dist/$APP-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "build/$APP.app" "dist/$APP-$VERSION.zip"
echo "==> Zipped dist/$APP-$VERSION.zip ($(du -h "dist/$APP-$VERSION.zip" | cut -f1))"
if [ "${1:-}" != "--no-install" ]; then
  pkill -x "$APP" 2>/dev/null || true
  sleep 0.6
  DEST=/Applications
  if [ ! -w "$DEST" ]; then DEST="$HOME/Applications"; mkdir -p "$DEST"; fi
  rm -rf "$DEST/$APP.app"
  cp -R "build/$APP.app" "$DEST/"
  echo "==> Installed to $DEST/$APP.app"
  open -g "$DEST/$APP.app"
  sleep 3
  if pgrep -x "$APP" >/dev/null; then echo "==> Running (pid $(pgrep -x "$APP"))"; else echo "==> NOT RUNNING"; fi
fi
echo "BUILD_OK"
