#!/usr/bin/env bash
# Build a distributable .dmg of LocalEdge AI for macOS.
#
# Usage: ./build_dmg.sh
#
# Output:  dist/LocalEdge-AI-<version>.dmg
#
# Uses only macOS built-ins (hdiutil, codesign). No Homebrew dependencies.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DISPLAY_NAME="LocalEdge AI"
VERSION="$(grep -E '^VERSION=' build_app.sh | head -1 | cut -d'"' -f2)"
DMG_NAME="LocalEdge-AI-${VERSION}"
DIST="$ROOT/dist"
APP="$DIST/$DISPLAY_NAME.app"

echo "==> Ensure macOS .app is fresh"
./build_app.sh >/dev/null

if [ ! -d "$APP" ]; then
    echo "✗ $APP missing — build_app.sh did not produce a bundle" >&2
    exit 1
fi

# Make sure the .app's main binary is actually a macOS Mach-O. If we just
# build_ios_app.sh'd over it, the binary would be iOS sim — refuse.
if ! file "$APP/Contents/MacOS/LocalEdgeAI" 2>/dev/null \
        | grep -q 'Mach-O 64-bit executable arm64'; then
    echo "✗ $APP/Contents/MacOS/LocalEdgeAI is not a macOS Mach-O." >&2
    echo "  Run ./build_app.sh first (build_ios_app.sh overwrites dist/)." >&2
    exit 1
fi

echo "==> Staging dmg contents"
STAGE="$(mktemp -d -t localedge-dmg)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
# Symlink so the user can drag-and-drop straight into /Applications.
ln -s /Applications "$STAGE/Applications"

# Optional: write a tiny README inside the dmg
cat > "$STAGE/Read Me.txt" <<EOF
LocalEdge AI ${VERSION}
by Prem Saran Kallakuri

To install:
  1. Drag "LocalEdge AI.app" onto the Applications shortcut.
  2. (First launch) Right-click LocalEdge AI in /Applications and choose
     Open — this is ad-hoc signed, not notarized.

For Mac users you also need to run a local model server:

    brew install llama.cpp
    llama-server --model <your-gemma>.gguf --port 8088 &

Then launch LocalEdge AI. See STARTER.md in the source repo for details.
EOF

RAW_DMG="$DIST/$DMG_NAME.unc.dmg"
FINAL_DMG="$DIST/$DMG_NAME.dmg"
rm -f "$RAW_DMG" "$FINAL_DMG"

echo "==> hdiutil create (raw UDRW)"
hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "$RAW_DMG" >/dev/null

echo "==> Compress to UDZO"
hdiutil convert "$RAW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
rm -f "$RAW_DMG"

# Ad-hoc sign the dmg for cleaner Gatekeeper UX
codesign --force --sign - "$FINAL_DMG" >/dev/null 2>&1 || true

SIZE=$(du -h "$FINAL_DMG" | awk '{print $1}')
echo "==> Built: $FINAL_DMG ($SIZE)"
