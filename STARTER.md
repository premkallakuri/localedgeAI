# LocalEdge AI — Starter & Builder's Guide

> Build your own on-device AI app on top of LocalEdge AI.
> By **Prem Saran Kallakuri**. Apache-2.0.

This guide is the fastest path from "I want to ship an AI app" to a working
universal SwiftUI binary that runs Gemma/Qwen/Llama models locally on macOS
and iOS — and a roadmap for adding your own agents, sub-apps, and features.

---

## Contents

1. [What this codebase is](#1-what-this-codebase-is)
2. [10-minute quickstart](#2-10-minute-quickstart)
3. [The mental model](#3-the-mental-model)
4. [Project layout](#4-project-layout)
5. [Add a new task (your own AI screen)](#5-add-a-new-task-your-own-ai-screen)
6. [Add a new agent (Hermes-style)](#6-add-a-new-agent-hermes-style)
7. [Add a new Skill](#7-add-a-new-skill)
8. [Add a new inference engine](#8-add-a-new-inference-engine)
9. [Theme it your way](#9-theme-it-your-way)
10. [Ship a sub-app — fork as a base](#10-ship-a-sub-app-—-fork-as-a-base)
11. [Build & run](#11-build--run)
12. [Cookbook — recipes for common features](#12-cookbook--recipes-for-common-features)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. What this codebase is

A single Swift Package that ships **two universal binaries from one source
tree**:

| Target | Runtime | Default model |
|---|---|---|
| **macOS 14+** | `llama.cpp` (`llama-server` on `127.0.0.1:8088`) | `gemma-3-4b-it-q4_0.gguf` |
| **iOS 17+** | **LiteRT-LM** (`CLiteRTLM.xcframework`) | first `.litertlm` in app Documents |

You can switch engines at runtime from the home-screen pill (`llama.cpp`,
`ollama`, or `LiteRT-LM`). Everything else — UI, navigation, chat, skills,
agents — is platform-agnostic SwiftUI.

The Android original (`local-edge-ai` sibling repo) inspired the palette,
screens, and task model. This is a clean reimplementation, not a port.

## 2. 10-minute quickstart

```bash
# 0. Prereqs (already installed on a typical dev Mac):
#    - Xcode 26+ in /Applications
#    - llama-server   (brew install llama.cpp)        ← for macOS engine
#    - Python 3 with Pillow                            ← for icon generation
#    - huggingface-cli (pip install -U "huggingface_hub[cli]")  ← for models

# 1. Get a model for macOS
brew install llama.cpp
# Place any .gguf model in ~/Downloads
llama-server --model ~/Downloads/gemma-3-4b-it-q4_0.gguf \
  --host 127.0.0.1 --port 8088 --ctx-size 4096 &

# 2. Build & run macOS
cd local-edge-ai-macos
python3 scripts/generate_icon.py     # one-time
./build_app.sh
open "dist/LocalEdge AI.app"

# 3. Build & run iOS Simulator (full Xcode required)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./build_ios_app.sh

# 4. Sideload a .litertlm model into the iOS sim
hf download litert-community/Qwen3-0.6B Qwen3-0.6B.litertlm \
  --local-dir /tmp/litertlm
DATA=$(xcrun simctl get_app_container booted com.localedge.ai data)
cp /tmp/litertlm/Qwen3-0.6B.litertlm "$DATA/Documents/LocalEdge/models/"
xcrun simctl terminate booted com.localedge.ai
xcrun simctl launch booted com.localedge.ai
```

## 3. The mental model

```
┌────────────────────────────────────────────────────────────────┐
│  RootView (NavigationStack)                                    │
│  ├─ HomeView           ── category tabs + tile grid            │
│  └─ TaskDetailView     ── per-task model selection landing     │
│       └─ <TaskName>Screen   ── chat surface for that task      │
│                                                                │
│  Shared:                                                       │
│  ├─ AppState            ── engine choice, models list          │
│  ├─ ChatSessionViewModel ─ one chat session's state            │
│  ├─ ChatPanel           ── reusable transcript + composer      │
│  ├─ MarkdownText        ── streaming-friendly Markdown render  │
│  └─ Theme + CustomColors ─ Material-3 palette                  │
│                                                                │
│  Engines (all conform to InferenceClient):                     │
│  ├─ OllamaClient        ── HTTP to localhost:11434             │
│  ├─ LlamaServerClient   ── OpenAI-compat HTTP to :8088         │
│  └─ LiteRtLmClient      ── C bindings to CLiteRTLM (iOS only)  │
└────────────────────────────────────────────────────────────────┘
```

**Key principles**

- One source of truth for tasks: `GalleryTask.allTasks` in `Models/Task.swift`
- One source of truth for skills: `Skill.bundled` in `Models/Skill.swift`
- Engines are interchangeable behind `protocol InferenceClient`
- Anything user-visible is wired through `AppState` so engine swaps are free
- Universal compile: any AppKit/UIKit call is wrapped in `#if os(macOS)`

## 4. Project layout

```
local-edge-ai-macos/
├── Package.swift              ← single executable target, both platforms
├── build_app.sh               ← macOS .app builder
├── build_ios_app.sh           ← iOS .app builder + sim installer
├── scripts/
│   └── generate_icon.py       ← Pillow → AppIcon.icns + iOS PNGs
├── Frameworks/
│   └── CLiteRTLM.xcframework  ← Google AI Edge LiteRT-LM (iOS only)
├── Sources/LocalEdgeAI/
│   ├── LocalEdgeAIApp.swift   ← @main, About dialog
│   ├── AppConfig.swift        ← name/version/author, loaded from JSON
│   ├── Theme.swift            ← Material-3 palettes (light + dark)
│   ├── Platform.swift         ← PlatformImage, AdaptiveSplit
│   ├── OllamaClient.swift     ← Ollama-flavored InferenceClient
│   ├── Models/
│   │   ├── Task.swift         ← GalleryTask + BuiltInTaskId
│   │   └── Skill.swift        ← Skill.bundled
│   ├── Services/
│   │   ├── AppState.swift     ← engine + models + skills
│   │   ├── InferenceEngine.swift ← protocol + LlamaServerClient
│   │   └── LiteRtLmClient.swift  ← iOS-only LiteRT-LM bridge
│   ├── ViewModels/
│   │   └── ChatSessionViewModel.swift
│   ├── Views/
│   │   ├── RootView.swift
│   │   ├── HomeView.swift
│   │   ├── TaskDetailView.swift      ← model picker landing
│   │   ├── TaskIconShape.swift       ← hex/squircle icon for hero
│   │   ├── SquareDrawerTile.swift    ← tile component
│   │   ├── ChatPanel.swift           ← transcript + composer
│   │   ├── MarkdownText.swift        ← live-rendering markdown
│   │   └── Tasks/
│   │       ├── ChatScreen.swift         ← AI Chat
│   │       ├── AgentChatScreen.swift    ← Agent + Skills
│   │       ├── HermesAgentScreen.swift  ← plan→execute→reflect
│   │       ├── AskImageScreen.swift     ← multimodal
│   │       ├── AudioScribeScreen.swift  ← placeholder
│   │       ├── PromptLabScreen.swift    ← sampler controls
│   │       ├── MobileActionsScreen.swift
│   │       ├── TinyGardenScreen.swift   ← 3x3 garden
│   │       ├── ModelManagerScreen.swift
│   │       └── BenchmarkScreen.swift
│   └── Resources/
│       ├── AppConfig.json
│       └── skills/
└── STARTER.md  ← this file
```

## 5. Add a new task (your own AI screen)

A "task" is a tile on the home grid that opens a model-picker landing and
then a chat surface. Five-step recipe:

1. **Pick an id** — extend `BuiltInTaskId` in `Models/Task.swift`:
   ```swift
   case llmCookCoach = "llm_cook_coach"
   ```
2. **Add the tile** — append to `GalleryTask.allTasks`:
   ```swift
   GalleryTask(
       id: .llmCookCoach,
       label: "Cook Coach",
       shortDescription: "Step-by-step recipe coaching",
       description: "Walks you through any recipe in real time…",
       category: .llm,
       iconName: "fork.knife.circle.fill",
       tint: Color(hex: 0x41A15F),
       newBadge: true,
       experimental: false,
       defaultSystemPrompt: "You are CookCoach, a friendly chef…"
   ),
   ```
3. **Write the screen** — copy `Views/Tasks/ChatScreen.swift` to
   `CookCoachScreen.swift`, rename the struct, and tweak the system prompt
   or sidebar. The `ChatPanel` does the rest.
4. **Wire navigation** — in `TaskDetailView.taskHostFor(model:)` add:
   ```swift
   case .llmCookCoach: CookCoachScreen(task: task, initialModel: model.name)
   ```
5. **Add to the colour table** — in three switch statements
   (`TaskIconShape.swift`, `SquareDrawerTile.swift`,
   `TaskDetailView.colorIndex`) pick a colour 0..3.

Build → your tile shows up under the category you chose, fully wired with
streaming, markdown rendering, model picker, and skills.

## 6. Add a new agent (Hermes-style)

An agent = a task whose **system prompt drives a loop**. See
`Views/Tasks/HermesAgentScreen.swift` for the reference:

```swift
defaultSystemPrompt: """
You are Hermes, an autonomous on-device agent. For every user goal:
1) PLAN — emit a numbered list of 3-6 steps.
2) EXECUTE — for each step, write "## Step N:" then a short paragraph.
3) REFLECT — write "## Reflection" and one sentence on whether the goal was met.
"""
```

The trick is structuring the system prompt so the model emits **predictable
Markdown sections** that look great in the chat (since `MarkdownText`
renders headings, lists, and code blocks natively).

Common agent patterns you can build by changing only the system prompt:

| Pattern | System-prompt shape |
|---|---|
| **ReAct** | `Thought:` → `Action:` → `Observation:` loop |
| **Tree-of-Thought** | Emit 3 candidate plans, score each, pick best |
| **Reflexion** | EXECUTE → SELF-CRITIQUE → REVISE |
| **Tool-router** | Emit `{"tool":"<name>","args":{…}}` JSON lines |
| **Persona stack** | Multiple system messages composed into one |

If you need real **tool calls** (not just JSON output the user sees), add a
parser that scans the streamed text for tool-call markers and executes
Swift code, then injects the result back into the conversation. See how
`TinyGardenScreen.swift` parses `{"action":"plant",…}` lines and updates
the 3×3 grid.

## 7. Add a new Skill

Skills are modular system-prompt extensions the user toggles in the Agent
Skills sidebar. Two steps:

1. Append to `Skill.bundled` in `Models/Skill.swift`:
   ```swift
   Skill(
       id: "summarize-pdf",
       name: "Summarize PDF",
       category: "built-in",
       description: "Distill a PDF into 5 bullet points + a TL;DR.",
       icon: "doc.text.magnifyingglass",
       systemPromptAddendum: "When given long text, output a 5-bullet…"
   ),
   ```
2. (Optional) If your skill needs *real* tool execution (file IO, web
   fetch), add a `runSkill(id:, input:)` method to your view model, parse
   the model's tool-call JSON, and dispatch. Otherwise the prompt
   addendum alone changes the model's behaviour.

## 8. Add a new inference engine

Three steps to plug in any new local runtime (MLX, CoreML, mlc-llm, etc.):

1. **Conform to the protocol** in `Services/InferenceEngine.swift`:
   ```swift
   protocol InferenceClient: Sendable {
       func listModels() async throws -> [OllamaModel]
       func streamChat(model:, messages:, temperature:, topP:, maxTokens:,
                       onToken:, onStats:) async throws
       func generateOnce(model:, prompt:, maxTokens:) async throws
           -> (text: String, evalCount: Int?, totalNs: Int64?)
   }
   ```
2. **Add a case** to the `InferenceEngine` enum:
   ```swift
   case mlx = "MLX"
   ```
3. **Wire it** in `AppState.switchEngine(to:)`:
   ```swift
   case .mlx: self.client = MlxClient()
   ```

That's it — the entire UI works against any new engine for free, because
nothing above `AppState` knows what the engine is.

## 9. Theme it your way

`Sources/LocalEdgeAI/Theme.swift` holds two colour tables — Material 3
`GalleryPalette` (primary/surface/onSurface ladder) and `GalleryCustomColors`
(brand gradient, tab pill, task gradients).

To rebrand:

- Edit `appTitleGradient` to change the hero text colour.
- Edit `taskBgGradients[0..3]` to swap the four task accent colours.
- Edit `tabHeaderBg` to change the active-tab pill colour.
- Edit `Resources/AppConfig.json` to change app name, version, tagline.

To regenerate the app icon with new colours: edit `scripts/generate_icon.py`
(`GRAD_TOP`, `GRAD_BOT`) and run `python3 scripts/generate_icon.py`.

## 10. Ship a sub-app — fork as a base

You want a single-purpose AI app (a writing coach, a recipe assistant, a
shopping advisor). Use this repo as your base:

```bash
cp -R local-edge-ai-macos my-cook-coach
cd my-cook-coach

# Strip back to just the one task you need
# - In Models/Task.swift, remove every tile except yours
# - In Views/Tasks/, delete unused screens
# - In TaskDetailView.swift / SquareDrawerTile.swift / TaskIconShape.swift,
#   remove the now-unused enum cases
# - Optional: remove the Home category tabs since you only have one tile

# Rebrand
- Resources/AppConfig.json  →  appName, tagline, defaultModel
- scripts/generate_icon.py  →  GRAD_TOP/GRAD_BOT for new accent
- build_app.sh / build_ios_app.sh  →  DISPLAY_NAME + BUNDLE_ID

# Re-skin
- Theme.swift  →  GalleryCustomColors.appTitleGradient

# Lock the user into your task on launch
- In RootView, route directly to TaskDetailView(task: GalleryTask.allTasks[0])
  instead of HomeView. Removes the home grid.

./build_app.sh
```

This is how you ship one app per use case while sharing the inference,
markdown, image, and engine plumbing across products.

## 11. Build & run

| What | Command |
|---|---|
| Generate icon | `python3 scripts/generate_icon.py` |
| Build macOS | `./build_app.sh` |
| Run macOS | `open "dist/LocalEdge AI.app"` |
| Build iOS Simulator | `./build_ios_app.sh` (requires full Xcode) |
| Install on real iPhone | use Xcode → Product → Run with the package |
| Smoke test (CLI) | see `iOS_BUILD.md` |
| Swap iOS model | `cp <model>.litertlm "$(xcrun simctl get_app_container booted com.localedge.ai data)/Documents/LocalEdge/models/"` |
| Tail iOS logs | `xcrun simctl spawn booted log show --process LocalEdgeAI --last 1m` |

## 12. Cookbook — recipes for common features

### Add streaming markdown rendering anywhere
`MarkdownText(source: text)` handles headings, lists, code blocks, inline
formatting. Works mid-stream — it re-renders as new tokens arrive.

### Attach an image to a chat
```swift
session.attach(imageData: data)   // base64-encodes + adds to next user msg
```
The `ChatPanel` already has a 📎 button on screens where
`showImageAttach: true` is set. iOS uses `PhotosPicker`, macOS uses
`NSOpenPanel`.

### Run a single-shot completion (no chat history)
```swift
let res = try await appState.client.generateOnce(
    model: appState.defaultModel,
    prompt: "Summarize: ...",
    maxTokens: 256
)
print(res.text, res.evalCount as Any, res.totalNs as Any)
```

### Toggle thinking mode (visible CoT)
On task screens that pass `showThinkingToggle: true` to `ChatPanel`, the
user sees a `Thinking mode` switch. When on, the system prompt is
augmented to emit a `<thinking>…</thinking>` block which is **stripped from
the visible bubble** by `MessageBubble.stripThinking(_:)`.

### Read benchmark stats
`ChatSessionViewModel` publishes `lastTokensPerSec` after each turn. The
`BenchmarkScreen` provides a UI to run repeated prompts and graph the
result cards.

### Deep-link from outside (URL scheme)
Add to your iOS `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array><dict>
  <key>CFBundleURLSchemes</key>
  <array><string>localedge</string></array>
</dict></array>
```
Then handle `localedge://run?prompt=...` in `RootView.onOpenURL { url in … }`.

## 13. Troubleshooting

| Symptom | Fix |
|---|---|
| macOS app shows offline | `llama-server --model <model>.gguf --port 8088 &` |
| iOS app shows offline | drop a `.litertlm` into `…/Documents/LocalEdge/models/` and relaunch |
| Build complains about CLiteRTLM on macOS | the binary target is gated `.when(platforms: [.iOS])` — clean build dir, rerun |
| `litert_lm_conversation_send_message_stream returned -1` | messages must be Gemini-style `{"parts":[{"text":…}],"role":"user"}` — see `LiteRtLmClient.contentJSON(role:text:)` |
| Window doesn't appear on Tahoe | the app uses `NSApplication.shared.setActivationPolicy(.regular)`; if it still doesn't show, run via Xcode |
| iOS Simulator inference is slow | expected — sim runs CPU-only. Real iPhone is 30-50× faster |
| Icon doesn't appear in Dock/Springboard | rerun `python3 scripts/generate_icon.py` then rebuild |
| Synthetic taps don't reach iOS sim | use real-device or Xcode UI tests; sim host-window forwarding has Tahoe issues |

---

**Made with ❤︎ by Prem Saran Kallakuri.** Apache-2.0.
