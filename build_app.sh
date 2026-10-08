#!/bin/bash
# Builds NotchMusic in release mode, wraps it into NotchMusic.app, and installs it to /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="NotchMusic.app"
INSTALL_DIR="/Applications"

echo "→ Building (release)…"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"

echo "→ Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/NotchMusic" "$APP/Contents/MacOS/NotchMusic"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Sign with the local "NotchMusic Local" certificate so the signature stays the same across builds
# and macOS remembers the Music permission. Falls back to ad-hoc signing if the certificate is missing.
SIGN_IDENTITY="NotchMusic Local"
if security find-certificate -c "$SIGN_IDENTITY" >/dev/null 2>&1; then
    echo "→ Code signing with \"${SIGN_IDENTITY}\"…"
    codesign --force --sign "$SIGN_IDENTITY" "$APP"
else
    echo "→ Code signing (ad-hoc; create the \"${SIGN_IDENTITY}\" certificate to keep permissions across builds)…"
    codesign --force --sign - "$APP"
fi

# A fixed location keeps "Launch at Login" working even if this project folder moves.
echo "→ Installing to ${INSTALL_DIR}…"
rm -rf "${INSTALL_DIR:?}/${APP}"
ditto "$APP" "${INSTALL_DIR}/${APP}"

echo "✓ Built and installed ${INSTALL_DIR}/${APP}"
