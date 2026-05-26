#!/usr/bin/env bash
# Builds LocalEdge AI as a release .app bundle for Apple Silicon macOS.
set -euo pipefail

APP_NAME="LocalEdgeAI"
DISPLAY_NAME="LocalEdge AI"
BUNDLE_ID="com.localedge.ai"
VERSION="0.4.0"
AUTHOR="Prem Saran Kallakuri"

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

DEFAULT_MODEL="$(python3 - <<'PY'
import json, pathlib
print(json.loads(pathlib.Path("Sources/LocalEdgeAI/Resources/AppConfig.json").read_text())["defaultModel"])
PY
)"

# --- Bundled inference engine (llama.cpp) + default model --------------------
if [ "${SKIP_ENGINE:-0}" != "1" ]; then
  echo "==> Fetch/build bundled llama-server"
  bash "$ROOT/scripts/fetch_llama_cpp.sh"
fi

if [ "${SKIP_MODEL_DOWNLOAD:-0}" != "1" ]; then
  echo "==> Download default GGUF model ($DEFAULT_MODEL)"
  bash "$ROOT/scripts/download_models.sh"
fi

echo "==> Building Swift package (release)..."
swift build -c release --arch arm64

BIN_PATH="$(swift build -c release --arch arm64 --show-bin-path)"
EXEC="$BIN_PATH/$APP_NAME"
if [ ! -x "$EXEC" ]; then
  echo "Build artifact not found at $EXEC"
  exit 1
fi

DIST="$ROOT/dist"
APP="$DIST/$DISPLAY_NAME.app"
echo "==> Assembling $APP"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$EXEC" "$APP/Contents/MacOS/$APP_NAME"

# Copy any .bundle resources produced by SwiftPM (e.g. LocalEdgeAI_LocalEdgeAI.bundle)
for b in "$BIN_PATH"/*.bundle; do
  [ -e "$b" ] && cp -R "$b" "$APP/Contents/Resources/"
done

# Embed app icon
if [ -f "$ROOT/build/icons/AppIcon.icns" ]; then
  cp "$ROOT/build/icons/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Bundle llama-server + default model (macOS offline inference)
ENGINE_SRC="$ROOT/build/engine/llama-server"
ENGINE_LIB_SRC="$ROOT/build/engine/lib"
MODEL_SRC="$ROOT/build/models/$DEFAULT_MODEL"
if [ -x "$ENGINE_SRC" ]; then
  mkdir -p "$APP/Contents/Resources/Engine/lib"
  cp "$ENGINE_SRC" "$APP/Contents/Resources/Engine/llama-server"
  chmod +x "$APP/Contents/Resources/Engine/llama-server"
  if [ -d "$ENGINE_LIB_SRC" ]; then
    cp "$ENGINE_LIB_SRC"/*.dylib "$APP/Contents/Resources/Engine/lib/" 2>/dev/null || true
  fi
  echo "==> Bundled llama-server + runtime libs"
else
  echo "⚠ No llama-server at $ENGINE_SRC — run scripts/fetch_llama_cpp.sh" >&2
fi
if [ -f "$MODEL_SRC" ]; then
  mkdir -p "$APP/Contents/Resources/Models"
  cp "$MODEL_SRC" "$APP/Contents/Resources/Models/$DEFAULT_MODEL"
  echo "==> Bundled model $DEFAULT_MODEL"
else
  echo "⚠ No model at $MODEL_SRC — run scripts/download_models.sh" >&2
fi

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>NSHumanReadableCopyright</key><string>© $(date +%Y) $AUTHOR. Apache-2.0 licensed.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key><true/>
    </dict>
</dict>
</plist>
PLIST

# --- Signing ---------------------------------------------------------------
# If a real Developer ID Application certificate is in the keychain we use it
# (the recipient gets a clean install, no Gatekeeper warning).
# Otherwise we fall back to a deep ad-hoc sign — Gatekeeper will still warn,
# but the signature itself is well-formed and the app launches reliably.
SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F\" '/Developer ID Application/{print $2; exit}')"
if [ -n "${SIGN_IDENTITY:-}" ]; then
    echo "==> Codesign with: $SIGN_IDENTITY"
    SIGN_FLAGS=(--force --options runtime --timestamp)
    SIGNER=("$SIGN_IDENTITY")
else
    echo "==> No Developer ID found — ad-hoc signing (Gatekeeper will warn)"
    SIGN_FLAGS=(--force --timestamp=none)
    SIGNER=("-")
fi

# Sign every embedded framework first (deepest first so codesign is consistent)
for f in "$APP/Contents/Frameworks"/*.framework "$APP/Contents/Frameworks"/*.dylib; do
  [ -e "$f" ] || continue
  codesign "${SIGN_FLAGS[@]}" --sign "${SIGNER[@]}" "$f" >/dev/null 2>&1 || true
done
# Sign bundled inference engine (ad-hoc / Developer ID must match the app signature)
if [ -x "$APP/Contents/Resources/Engine/llama-server" ]; then
  codesign --force --sign "${SIGNER[@]}" "${SIGN_FLAGS[@]}" \
    "$APP/Contents/Resources/Engine/llama-server" >/dev/null 2>&1 || true
fi
# Then the main bundle (deep so any nested helpers also get signed)
codesign "${SIGN_FLAGS[@]}" --deep --sign "${SIGNER[@]}" "$APP" >/dev/null 2>&1 || true

# Strip the quarantine attribute we just freshly created — files we made
# locally never had it but recursing here keeps the script idempotent for
# .apps that were previously downloaded.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "==> Built: $APP"
echo "    Run with:  open \"$APP\""
echo "    Or:        \"$APP/Contents/MacOS/$APP_NAME\""
