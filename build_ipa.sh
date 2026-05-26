#!/usr/bin/env bash
# Build an *unsigned* iOS device .ipa of LocalEdge AI.
#
# Without a paid Apple Developer account we can't ship a signed .ipa that
# installs over double-click. The recipient must sideload via:
#
#   • Xcode  → Window → Devices and Simulators → drag the .ipa
#   • AltStore / SideStore (free, uses their personal Apple ID)
#   • Sideloadly (free)
#   • Apple Configurator 2 (Mac App Store)
#
# Anyone with Xcode + a free Apple ID can install on their own iPhone for
# 7 days at a time. With a paid developer account it's a one-year cert.
#
# Output:  dist/LocalEdge-AI-<version>.ipa
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="LocalEdgeAI"
DISPLAY_NAME="LocalEdge AI"
BUNDLE_ID="com.localedge.ai"
VERSION="$(grep -E '^VERSION=' build_app.sh | head -1 | cut -d'"' -f2)"
IOS_MIN="17.0"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DERIVED="$ROOT/build/ios-device"
PRODUCTS="$DERIVED/Build/Products/Release-iphoneos"

echo "==> xcodebuild for iOS device (arm64 Release, unsigned)"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  ARCHS="arm64" \
  ONLY_ACTIVE_ARCH=NO \
  build >/dev/null

BIN="$PRODUCTS/$APP_NAME"
[ -x "$BIN" ] || { echo "missing $BIN"; exit 1; }

# Assemble flat iOS .app bundle
STAGE="$(mktemp -d -t localedge-ipa)"
trap 'rm -rf "$STAGE"' EXIT
APP="$STAGE/Payload/$DISPLAY_NAME.app"
mkdir -p "$APP"

cp "$BIN" "$APP/$APP_NAME"

# Inject @executable_path/Frameworks rpath so CLiteRTLM resolves at runtime.
install_name_tool -add_rpath "@executable_path/Frameworks" "$APP/$APP_NAME" 2>/dev/null || true

# SwiftPM resource bundles
for b in "$PRODUCTS"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/"
done

# Embed every framework (CLiteRTLM)
mkdir -p "$APP/Frameworks"
for fw in "$PRODUCTS"/*.framework; do
  [ -d "$fw" ] || continue
  cp -R "$fw" "$APP/Frameworks/"
done

# Icons
if [ -d "$ROOT/build/icons/ios" ]; then
  cp "$ROOT"/build/icons/ios/AppIcon-*.png "$APP/" 2>/dev/null || true
fi

# iOS device Info.plist (no signing, no provisioning, recipient self-signs)
cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array>
    <key>MinimumOSVersion</key><string>$IOS_MIN</string>
    <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
    <key>UILaunchScreen</key><dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>CFBundleIcons</key>
    <dict>
        <key>CFBundlePrimaryIcon</key>
        <dict>
            <key>CFBundleIconFiles</key>
            <array>
                <string>AppIcon-60</string>
                <string>AppIcon-76</string>
                <string>AppIcon-120</string>
                <string>AppIcon-152</string>
                <string>AppIcon-167</string>
                <string>AppIcon-180</string>
            </array>
            <key>CFBundleIconName</key><string>AppIcon</string>
        </dict>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>© $(date +%Y) Prem Saran Kallakuri. Apache-2.0.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key><true/>
    </dict>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Attach images to your chat for the Ask Image task.</string>
    <key>NSCameraUsageDescription</key>
    <string>Capture images to send to the on-device model.</string>
</dict>
</plist>
PLIST

# Zip the Payload/ tree into a .ipa
IPA="$ROOT/dist/LocalEdge-AI-${VERSION}.ipa"
mkdir -p "$ROOT/dist"
rm -f "$IPA"
(cd "$STAGE" && zip -qr "$IPA" Payload)

SIZE=$(du -h "$IPA" | awk '{print $1}')
echo "==> Built: $IPA ($SIZE)"
echo "    Recipient must sideload (Xcode/AltStore/Sideloadly). See INSTALL.txt."
