#!/usr/bin/env bash
# Build ONE distributable .dmg containing both the macOS .app and the iOS .ipa,
# with a proper volume icon, deep ad-hoc signing, and Gatekeeper-aware
# install instructions.
#
# IMPORTANT — about "unidentified developer"
# ------------------------------------------
# macOS Gatekeeper only fully accepts apps signed with a paid Apple Developer
# ID certificate ($99/yr) AND notarized through Apple's notary service. This
# script builds the next-best thing: a deep-signed-with-hardened-runtime app
# in a polished DMG, plus a clear bypass procedure in INSTALL.txt. Recipients
# right-click → Open the first time and the app launches cleanly afterward.
#
# When a real "Developer ID Application" cert is in the build machine's
# keychain, build_app.sh automatically picks it up — no edits needed — and
# the warning goes away entirely.
#
# Output:  dist/LocalEdge-AI-<version>-universal.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DISPLAY_NAME="LocalEdge AI"
VERSION="$(grep -E '^VERSION=' build_app.sh | head -1 | cut -d'"' -f2)"
DMG_NAME="LocalEdge-AI-${VERSION}-universal"
DIST="$ROOT/dist"

APP="$DIST/$DISPLAY_NAME.app"
IPA="$DIST/LocalEdge-AI-${VERSION}.ipa"

echo "==> Build fresh artifacts"
./build_app.sh >/dev/null
if [ ! -f "$IPA" ]; then
    ./build_ipa.sh >/dev/null
fi

# Refuse to build if the .app's binary isn't a macOS Mach-O.
if ! file "$APP/Contents/MacOS/LocalEdgeAI" 2>/dev/null \
        | grep -q 'Mach-O 64-bit executable arm64'; then
    echo "✗ $APP is not a macOS Mach-O. Aborting." >&2
    exit 1
fi

# Generate the icon assets if missing
if [ ! -f "$ROOT/build/icons/AppIcon.icns" ]; then
    python3 scripts/generate_icon.py >/dev/null
fi

echo "==> Stage dmg contents"
STAGE="$(mktemp -d -t localedge-univ)"
trap 'rm -rf "$STAGE"' EXIT

cp -R "$APP" "$STAGE/"
cp "$IPA" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# ── Volume icon: put a .VolumeIcon.icns at the dmg root, then we'll mark the
#    mounted volume with the custom-icon flag (`SetFile -a C`) once mounted.
cp "$ROOT/build/icons/AppIcon.icns" "$STAGE/.VolumeIcon.icns"

cat > "$STAGE/INSTALL.txt" <<EOF
LocalEdge AI ${VERSION} — Universal Distribution
═══════════════════════════════════════════════════════════════════════
by Prem Saran Kallakuri

What's inside
─────────────
• LocalEdge AI.app              ← installs on macOS 14 (Sonoma) and newer
• LocalEdge-AI-${VERSION}.ipa   ← sideloads on iOS 17 and newer
• Applications                  ← drag-target for the Mac install

Apple does not allow a single tap to install on both macOS and iOS, so
pick the right artifact below.

────────────────────────────────────────────────────────────────────────
▶ MAC INSTALL  (macOS 14+, Apple Silicon)
────────────────────────────────────────────────────────────────────────

  1. Drag "LocalEdge AI" onto the "Applications" shortcut to the right.
  2. Open Launchpad (or /Applications/) and click LocalEdge AI ONCE.
       — You may see: "LocalEdge AI cannot be opened because it is
         from an unidentified developer." That's because this build is
         ad-hoc signed, not Apple-notarized. To open it the first time:

      a) Right-click (or Control-click) LocalEdge AI in /Applications
      b) Choose Open
      c) Click Open in the confirmation dialog

       Mac will remember this exception. From the second launch onward
       the app opens normally.

       If you're on macOS 15+ and the right-click trick doesn't work:
         System Settings → Privacy & Security →
           scroll to the bottom →
           "LocalEdge AI was blocked"  →  Click "Open Anyway"

  3. Launch LocalEdge AI — llama.cpp and the default Gemma model are
     bundled inside the app. The first launch starts the local inference
     server automatically (may take ~10–20 seconds while the model loads).

     The top-right pill should show "llama.cpp ● 1 model(s)" when ready.

     No Homebrew, Ollama, or manual model download required on macOS.

────────────────────────────────────────────────────────────────────────
▶ IPHONE / IPAD INSTALL  (iOS 17+)
────────────────────────────────────────────────────────────────────────

The .ipa is UNSIGNED. iOS refuses to install unsigned apps from a tap.
Use any ONE of these free tools to re-sign it with YOUR Apple ID:

  Option A — Xcode 16+ on a Mac (easiest if you already have it):
    1. Connect iPhone via USB and trust the Mac on the device.
    2. Xcode → Window → Devices and Simulators → select your phone.
    3. In "Installed Apps", drag the .ipa file in.
    4. Sign in with your Apple ID in Xcode → Settings → Accounts;
       Xcode will auto-create a free personal team certificate.
       The app installs and lasts 7 days before needing re-sign on a
       free Apple ID — or 1 year with a paid Developer Account.

  Option B — AltStore / SideStore (no Mac required after setup):
    https://altstore.io  →  "+"  →  pick the .ipa  →  done.

  Option C — Sideloadly (Mac/Win, one-tap):
    https://sideloadly.io  →  drop the .ipa  →  enter Apple ID  →  Start.

After installing on the phone, side-load a .litertlm model file via the
Files app or Xcode's app-container browser. The app expects models under
Documents/LocalEdge/models/. Non-gated chat-tuned options:

  • litert-community/Qwen3-0.6B               — 586 MB
  • litert-community/gemma-4-E2B-it-litert-lm — 2.0 GB (best quality)

────────────────────────────────────────────────────────────────────────
Source, docs, agent recipes
────────────────────────────────────────────────────────────────────────

See STARTER.md in the source repo for the full developer walkthrough —
how the app is built, how to add a new task or agent, how to swap engines,
and how to use this as the base for your own AI app.
EOF

# ── Build the dmg in two passes so we can set the volume icon. ─────────────
RAW="$DIST/$DMG_NAME.unc.dmg"
FINAL="$DIST/$DMG_NAME.dmg"
rm -f "$RAW" "$FINAL"

echo "==> hdiutil create (writable UDRW so we can set the volume icon)"
hdiutil create \
    -volname "$DISPLAY_NAME" \
    -srcfolder "$STAGE" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "$RAW" >/dev/null

# Mount the writable image and set the volume icon
ATTACH_OUT=$(hdiutil attach -readwrite -noverify -noautoopen "$RAW")
MOUNT_DEV=$(echo "$ATTACH_OUT" | grep -E '^/dev/disk[0-9]+s' | head -1 | awk '{print $1}')
MOUNT_PT=$(echo "$ATTACH_OUT" | grep '/Volumes/' | tail -1 | sed -E 's/^[^ 	]+[ 	]+[^ 	]+[ 	]+//')

# Make the volume root writable for the user before touching FinderInfo
chmod -R u+w "$MOUNT_PT" 2>/dev/null || true

echo "==> Set volume custom-icon flag (kHasCustomIcon)"
# Sanity check: the .VolumeIcon.icns is already at the volume root.
# Setting kHasCustomIcon in the FinderInfo tells Finder to use it.
# Try SetFile first, then xattr fallback.
SETFILE="$(command -v SetFile || xcrun --find SetFile 2>/dev/null || true)"
if [ -x "$SETFILE" ]; then
    "$SETFILE" -a C "$MOUNT_PT" 2>/dev/null || true
fi
# Verify the bit landed; if not, try the explicit FinderInfo write.
INFO=$(xattr -px com.apple.FinderInfo "$MOUNT_PT" 2>/dev/null | tr -d ' \n' || true)
# kHasCustomIcon = bit 10 of the Finder flags (bytes 8-9, big-endian).
# Byte index 8 should have bit 2 (0x04) set ⇒ "00 04" in the flags slot.
if ! echo "$INFO" | head -c 20 | grep -qi '04'; then
    /usr/bin/python3 - "$MOUNT_PT" <<'PYEOF' 2>/dev/null || true
import os, sys
finfo = b'\x00' * 8 + b'\x04\x00' + b'\x00' * 22   # kHasCustomIcon at FinderFlags
try:
    os.setxattr(sys.argv[1], 'com.apple.FinderInfo', finfo, 0)
except Exception as e:
    print('setxattr failed:', e, file=sys.stderr)
PYEOF
fi

# Lay out the window — set a custom size and position .app + Applications.
echo "==> Configure dmg window layout via AppleScript"
osascript <<EOF 2>/dev/null || true
tell application "Finder"
    tell disk "$DISPLAY_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 200, 900, 580}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "LocalEdge AI.app" of container window to {180, 180}
        set position of item "Applications"     of container window to {520, 180}
        set position of item "LocalEdge-AI-${VERSION}.ipa" of container window to {180, 320}
        set position of item "INSTALL.txt"      of container window to {520, 320}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Make sure changes are written
sync; sync

hdiutil detach "$MOUNT_DEV" >/dev/null 2>&1 || true

echo "==> Convert to compressed read-only UDZO"
hdiutil convert "$RAW" -format UDZO -imagekey zlib-level=9 -o "$FINAL" >/dev/null
rm -f "$RAW"

# Sign the dmg itself (with the same identity build_app.sh used, or ad-hoc)
SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F\" '/Developer ID Application/{print $2; exit}')"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    echo "==> Codesign dmg with Developer ID"
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$FINAL" >/dev/null
else
    echo "==> Ad-hoc sign the dmg"
    codesign --force --sign - "$FINAL" >/dev/null 2>&1 || true
fi

SIZE=$(du -h "$FINAL" | awk '{print $1}')
echo
echo "==> Built: $FINAL ($SIZE)"
echo
echo "Send that one file. Mac users drag-to-Applications + right-click → Open"
echo "the first time. iPhone users sideload the .ipa (see INSTALL.txt)."
