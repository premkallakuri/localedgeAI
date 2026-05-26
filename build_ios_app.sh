#!/usr/bin/env bash
# Builds LocalEdge AI as an iOS Simulator .app bundle, installs it into a
# booted simulator, and launches it.
#
# Requires full Xcode (not just Command Line Tools).
set -euo pipefail

APP_NAME="LocalEdgeAI"
DISPLAY_NAME="LocalEdge AI"
BUNDLE_ID="com.localedge.ai"
VERSION="0.3.0"
IOS_MIN="17.0"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DERIVED="$ROOT/build/ios-sim"

echo "==> xcodebuild for iOS Simulator (arm64 + x86_64)"
xcodebuild \
  -scheme "$APP_NAME" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  build >/dev/null

PRODUCTS="$DERIVED/Build/Products/Debug-iphonesimulator"
BIN="$PRODUCTS/$APP_NAME"
[ -x "$BIN" ] || { echo "missing $BIN"; exit 1; }

DIST="$ROOT/dist"
APP="$DIST/$DISPLAY_NAME.app"
echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP"

# iOS .app bundles are FLAT (no Contents/MacOS). Executable + Info.plist + resources at the root.
cp "$BIN" "$APP/$APP_NAME"

# The SwiftPM-built executable only has rpaths for /usr/lib/swift and a
# nonexistent 'lib/' next to it. iOS app convention is @executable_path/Frameworks,
# so inject that so dyld finds the embedded CLiteRTLM.framework on launch.
install_name_tool -add_rpath "@executable_path/Frameworks" "$APP/$APP_NAME" 2>/dev/null || true

# Copy the SwiftPM-generated resource bundle.
for b in "$PRODUCTS"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/"
done

# Embed iOS app icon PNGs at the bundle root (flat iOS .app layout).
if [ -d "$ROOT/build/icons/ios" ]; then
  cp "$ROOT"/build/icons/ios/AppIcon-*.png "$APP/" 2>/dev/null || true
fi

# Embed every framework xcodebuild produced (CLiteRTLM, etc.) under Frameworks/.
mkdir -p "$APP/Frameworks"
for fw in "$PRODUCTS"/*.framework; do
  [ -d "$fw" ] || continue
  cp -R "$fw" "$APP/Frameworks/"
  # Re-sign each embedded framework so the simulator's dyld will accept it.
  codesign --force --sign - --timestamp=none "$APP/Frameworks/$(basename "$fw")" >/dev/null 2>&1 || true
done

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
    <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
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

# Ad-hoc re-sign for the simulator
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || true

echo "==> Built iOS .app: $APP"

# Pick a simulator
DEVICE="${IOS_DEVICE:-iPhone 17}"
echo "==> Boot simulator: $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
open -a Simulator

# Wait until booted
for i in 1 2 3 4 5 6 7 8 9 10; do
    state=$(xcrun simctl list devices booted | grep -m1 "$DEVICE" || true)
    [ -n "$state" ] && break
    sleep 1
done

echo "==> Install + launch"
xcrun simctl install booted "$APP"
xcrun simctl launch booted "$BUNDLE_ID"

echo "==> Done. App should be visible in the Simulator window."
