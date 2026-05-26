import SwiftUI

/// Mirrors com.google.ai.edge.gallery.data.BuiltInTaskId
enum BuiltInTaskId: String, CaseIterable, Identifiable {
    case llmChat          = "llm_chat"
    case llmPromptLab     = "llm_prompt_lab"
    case llmAskImage      = "llm_ask_image"
    case llmAskAudio      = "llm_ask_audio"
    case llmAgentChat     = "llm_agent_chat"
    case llmHermesAgent   = "llm_hermes_agent"
    case llmMobileActions = "llm_mobile_actions"
    case llmTinyGarden    = "llm_tiny_garden"
    case modelManager     = "model_manager"
    case benchmark        = "benchmark"

    var id: String { rawValue }
}

struct GalleryCategory: Identifiable, Hashable {
    let id: String
    let label: String

    static let llm           = GalleryCategory(id: "llm", label: "LLM")
    static let agents        = GalleryCategory(id: "agents", label: "Agents")
    static let experimental  = GalleryCategory(id: "experimental", label: "Experimental")
    static let library       = GalleryCategory(id: "library", label: "Library")
}

/// Mirrors com.google.ai.edge.gallery.data.Task — display data for a tile on the Home screen.
struct GalleryTask: Identifiable, Hashable {
    let id: BuiltInTaskId
    let label: String
    let shortDescription: String
    let description: String
    let category: GalleryCategory
    let iconName: String          // SF Symbol
    let tint: Color
    let newBadge: Bool
    let experimental: Bool
    let defaultSystemPrompt: String

    static let allTasks: [GalleryTask] = [
        GalleryTask(
            id: .llmChat,
            label: "AI Chat",
            shortDescription: "Multi-turn chat with thinking mode",
            description: "Engage in fluid, multi-turn conversations with on-device LLMs. Toggle Thinking Mode on supported models to see step-by-step reasoning.",
            category: .llm,
            iconName: "bubble.left.and.bubble.right.fill",
            tint: Color(hex: 0x4285F4),
            newBadge: false,
            experimental: false,
            defaultSystemPrompt: "You are LocalEdge, a helpful on-device AI assistant running fully offline on the user's Mac. Be concise and accurate."
        ),
        GalleryTask(
            id: .llmAgentChat,
            label: "Agent Skills",
            shortDescription: "Augment your model with tools",
            description: "Transform your LLM from a conversationalist into a proactive assistant. Use modular Skills like Wikipedia for fact-grounding, interactive maps, hashing, QR codes, and more.",
            category: .agents,
            iconName: "puzzlepiece.extension.fill",
            tint: Color(hex: 0x9C27B0),
            newBadge: true,
            experimental: false,
            defaultSystemPrompt: "You are LocalEdge Agent. You can invoke registered Skills by emitting a JSON tool-call line, e.g. {\"skill\":\"query-wikipedia\",\"args\":{\"query\":\"…\"}}. Prefer concise replies that cite the skill output."
        ),
        GalleryTask(
            id: .llmAskImage,
            label: "Ask Image",
            shortDescription: "Multimodal visual Q&A",
            description: "Use multimodal power to identify objects, solve visual puzzles, or get detailed descriptions of images. Drag an image into the chat or paste from the clipboard.",
            category: .llm,
            iconName: "photo.on.rectangle.angled",
            tint: Color(hex: 0x34A853),
            newBadge: false,
            experimental: false,
            defaultSystemPrompt: "You are LocalEdge Vision. Describe images carefully and answer the user's question."
        ),
        GalleryTask(
            id: .llmAskAudio,
            label: "Audio Scribe",
            shortDescription: "Transcribe & translate speech",
            description: "Transcribe and translate voice recordings into text using on-device language models.",
            category: .llm,
            iconName: "waveform.and.mic",
            tint: Color(hex: 0xEA4335),
            newBadge: false,
            experimental: true,
            defaultSystemPrompt: "You are LocalEdge Scribe. Transcribe audio clips faithfully and translate when requested."
        ),
        GalleryTask(
            id: .llmPromptLab,
            label: "Prompt Lab",
            shortDescription: "Test prompts with full control",
            description: "A dedicated workspace to test single-turn prompts with granular control over temperature, top-k, and top-p.",
            category: .llm,
            iconName: "flask.fill",
            tint: Color(hex: 0xFBBC05),
            newBadge: false,
            experimental: false,
            defaultSystemPrompt: ""
        ),
        GalleryTask(
            id: .llmHermesAgent,
            label: "Hermes Agent",
            shortDescription: "Plan → act → reflect loop",
            description: "An on-device autonomous agent that decomposes a goal into a numbered plan, executes each step, and reflects on the result before moving on. A reference pattern you can fork to build your own agents.",
            category: .agents,
            iconName: "shippingbox.and.arrow.backward.fill",
            tint: Color(hex: 0xE25F57),
            newBadge: true,
            experimental: true,
            defaultSystemPrompt: """
            You are Hermes, an autonomous on-device agent. For every user goal, follow this loop exactly:

            1) PLAN — emit a numbered Markdown list of 3-6 concrete steps to achieve the goal.
            2) EXECUTE — for each step, write "## Step N:" then a single short paragraph performing that step.
            3) REFLECT — after the last step, write "## Reflection" and one sentence on whether the goal was met.

            Keep total output under 250 words. Stay grounded; if information is missing, say so in Reflect.
            """
        ),
        GalleryTask(
            id: .llmMobileActions,
            label: "Mobile Actions",
            shortDescription: "Offline function-calling",
            description: "Unlock automated device controls and tool-use powered by function-calling models.",
            category: .agents,
            iconName: "bolt.horizontal.circle.fill",
            tint: Color(hex: 0x00BCD4),
            newBadge: false,
            experimental: true,
            defaultSystemPrompt: ""
        ),
        GalleryTask(
            id: .llmTinyGarden,
            label: "Tiny Garden",
            shortDescription: "Plant with natural language",
            description: "A fun, experimental mini-game that uses natural language to plant and harvest a virtual garden.",
            category: .experimental,
            iconName: "leaf.fill",
            tint: Color(hex: 0x4CAF50),
            newBadge: false,
            experimental: true,
            defaultSystemPrompt: "You are the Tiny Garden gamemaster. Translate the user's natural-language gardening commands into terse plant/harvest actions."
        ),
        GalleryTask(
            id: .modelManager,
            label: "Model Manager",
            shortDescription: "Browse, pull, and inspect models",
            description: "Manage your local model library. View sizes, switch defaults, and run benchmarks on each.",
            category: .library,
            iconName: "shippingbox.fill",
            tint: Color(hex: 0x607D8B),
            newBadge: false,
            experimental: false,
            defaultSystemPrompt: ""
        ),
        GalleryTask(
            id: .benchmark,
            label: "Benchmark",
            shortDescription: "Measure tokens per second",
            description: "Run benchmark tests against any model to understand exactly how it performs on your specific hardware.",
            category: .library,
            iconName: "speedometer",
            tint: Color(hex: 0xFF9800),
            newBadge: false,
            experimental: false,
            defaultSystemPrompt: ""
        ),
    ]
}
