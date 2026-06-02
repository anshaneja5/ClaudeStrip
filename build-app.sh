#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="ClaudeStrip"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SRC="$SCRIPT_DIR/ClaudeStrip/Sources"
BRIDGE="$SCRIPT_DIR/ClaudeStrip/App/DFR-Bridging-Header.h"

echo "Building $APP_NAME.app ..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

COMMON_FLAGS=(
  -import-objc-header "$BRIDGE"
  -F /System/Library/PrivateFrameworks -framework DFRFoundation
  -framework Cocoa
  -framework SwiftUI
  -framework Charts
  -swift-version 5
  -O
)

build_arch () {
  local arch="$1"
  swiftc -o "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-${arch}" \
    "$SRC"/Core/*.swift \
    "$SRC"/App/*.swift \
    "${COMMON_FLAGS[@]}" \
    -target "${arch}-apple-macosx13.0"
}

echo "[1/4] Compiling (arm64 + x86_64)..."
build_arch arm64
build_arch x86_64
lipo -create \
  "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-arm64" \
  "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-x86_64" \
  -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
rm "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-arm64" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}-x86_64"
echo "  universal binary (arm64 + x86_64)"

echo "[2/4] Copying Info.plist..."
cp "$SCRIPT_DIR/ClaudeStrip/App/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "[3/4] Bundling install scripts..."
cp "$SCRIPT_DIR/post-install.sh" "$SCRIPT_DIR/uninstall.sh" "$APP_BUNDLE/Contents/Resources/"

echo "[4/4] Zipping..."
( cd "$BUILD_DIR" && ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip" )

echo "Done -> $APP_BUNDLE"
echo "Packaged -> $BUILD_DIR/$APP_NAME.zip"
