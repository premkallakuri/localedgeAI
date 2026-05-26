# Universal (iOS + macOS) build

The same `Package.swift` ships both targets.

```
platforms: [
    .macOS(.v14),
    .iOS(.v17),
],
```

## macOS (already verified)

```bash
swift build -c release            # builds for the host (macOS)
./build_app.sh                    # assembles "LocalEdge AI.app"
open "dist/LocalEdge AI.app"
```

## iOS — requires full Xcode (not just Command Line Tools)

```bash
# 1. Install Xcode and the iOS SDK
xcode-select --install
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 2. Sanity-check the iOS SDK is now visible
xcrun --sdk iphoneos --show-sdk-path           # should print a real path
xcrun --sdk iphonesimulator --show-sdk-path

# 3. Build for an iOS simulator
xcodebuild \
  -scheme LocalEdgeAI \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/ios \
  build

# 4. Run the simulator build
xcrun simctl boot 'iPhone 15 Pro' || true
open -a Simulator
xcrun simctl install booted build/ios/Build/Products/Debug-iphonesimulator/LocalEdgeAI.app
xcrun simctl launch booted com.localedge.ai
```

## Cross-platform shims in the source

| Concern | macOS | iOS |
|---|---|---|
| Image type | `NSImage` | `UIImage` (via `PlatformImage` typealias in `Platform.swift`) |
| Image picker | `NSOpenPanel` | `PhotosPicker` (call sites already handle both via `openImagePicker()`) |
| Side-by-side panels | `HSplitView` | `HStack` (via `AdaptiveSplit` in `Platform.swift`) |
| Activation policy | `NSApp.setActivationPolicy` | (no-op, wrapped in `#if os(macOS)`) |
| About dialog | `NSAlert` | (no-op on iOS — could be replaced with a SwiftUI sheet later) |
| Window sizing | `.frame(minWidth:minHeight:)` | (no-op on iOS) |

## Inference engine on iOS vs macOS

- **iOS** — the `CLiteRTLM.xcframework` (v0.12.0) **already ships an `ios-arm64` slice and an `ios-arm64_x86_64-simulator` slice**, so on iOS you can link the actual LiteRT-LM engine — the same one the Android app uses. Wire it via a `binaryTarget` in `Package.swift` and call into the C API from `LiteRtLmClient`.
- **macOS** — no macOS slice in v0.12.0 yet. The app falls through to llama.cpp / `llama-server` via the same `InferenceClient` protocol.

## Bundling the xcframework as a binary target (when you're ready)

```swift
.binaryTarget(
    name: "CLiteRTLM",
    path: "Frameworks/CLiteRTLM.xcframework"
),
.executableTarget(
    name: "LocalEdgeAI",
    dependencies: ["CLiteRTLM"],
    path: "Sources/LocalEdgeAI"
)
```

Then in `LiteRtLmClient`, replace the stub with `import CLiteRTLM` and call the C API.
