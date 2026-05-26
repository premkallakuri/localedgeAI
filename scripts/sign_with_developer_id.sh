#!/usr/bin/env bash
# Re-sign the .app + .dmg with your Apple Developer ID Application certificate.
# Run this ONCE after enrolling in the Apple Developer Program ($99/yr) and
# installing your "Developer ID Application: <Name> (<TeamID>)" cert into your
# Keychain.
#
# Usage:
#   ./scripts/sign_with_developer_id.sh "Developer ID Application: Your Name (ABCDE12345)"
#
# After this, optionally notarize:
#   xcrun notarytool submit dist/LocalEdge-AI-X.Y.Z-universal.dmg \
#       --apple-id <you@apple-id> --team-id <TEAMID> --password <app-specific-pw> --wait
#   xcrun stapler staple dist/LocalEdge-AI-X.Y.Z-universal.dmg
#
# Once notarized + stapled, the dmg installs with zero Gatekeeper warnings.
set -euo pipefail

IDENTITY="${1:-}"
if [ -z "$IDENTITY" ]; then
    echo "usage: $0 \"Developer ID Application: Name (TEAMID)\"" >&2
    echo
    echo "Identities currently in your keychain:" >&2
    security find-identity -v -p codesigning 2>&1
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/LocalEdge AI.app"
DMG=$(ls -t "$ROOT"/dist/LocalEdge-AI-*-universal.dmg 2>/dev/null | head -1)

[ -d "$APP" ] || { echo "$APP not found — run ./build_app.sh first"; exit 1; }

echo "==> Re-sign .app with $IDENTITY"
for f in "$APP/Contents/Frameworks"/*.framework "$APP/Contents/Frameworks"/*.dylib; do
    [ -e "$f" ] || continue
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$f"
done
codesign --force --options runtime --timestamp --deep --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

if [ -n "$DMG" ]; then
    echo "==> Re-sign $DMG with $IDENTITY"
    codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi

echo
echo "==> Done."
echo "Next: notarize + staple for a fully clean install:"
echo "    xcrun notarytool submit \"\$DMG\" --apple-id <you> --team-id <TEAM> \\"
echo "        --password <app-specific-pw> --wait"
echo "    xcrun stapler staple \"\$DMG\""
