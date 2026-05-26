# LocalEdge AI

**On-device generative AI for macOS and iOS.** A native SwiftUI app that runs Gemma, Qwen, and other open-source models locally — fully offline, fully private.

Universal Swift package: **macOS 14+** (llama.cpp / Ollama) and **iOS 17+** (LiteRT-LM via `CLiteRTLM.xcframework`).

## Quick start

```bash
git clone https://github.com/premkallakuri/localedgeAI.git
cd localedgeAI
open Package.swift          # Xcode
python3 scripts/generate_icon.py
./build_app.sh              # macOS
./build_ios_app.sh          # iOS Simulator
```

See [STARTER.md](STARTER.md) and [iOS_BUILD.md](iOS_BUILD.md) for full build and App Store notes.

## Repository layout

| Path | Contents |
|------|----------|
| `Package.swift`, `Sources/` | SwiftUI app (macOS + iOS) |
| `Frameworks/` | `CLiteRTLM.xcframework` (iOS inference) |
| `scripts/`, `build_*.sh` | Icons, macOS/iOS/IPA builders |
| `fastos-boot/` | DGX SPARK FASTOS boot media (see [fastos-boot/DOWNLOAD.md](fastos-boot/DOWNLOAD.md)) |

## License

Apache-2.0 — see [LICENSE](LICENSE).
