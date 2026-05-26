import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
import UniformTypeIdentifiers
#endif

@MainActor
final class ChatSessionViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input: String = ""
    @Published var isStreaming: Bool = false
    @Published var lastTokensPerSec: Double? = nil
    @Published var statusLine: String = ""
    @Published var temperature: Double = 0.7
    @Published var topP: Double = 0.95
    @Published var maxTokens: Int = 1024
    @Published var systemPrompt: String
    @Published var attachedImages: [Data] = []  // base64 will be encoded on send
    @Published var enabledSkillIds: Set<String> = []
    @Published var thinkingMode: Bool = false
    @Published var model: String

    let task: GalleryTask
    weak var appState: AppState?
    let skills: [Skill]

    init(task: GalleryTask) {
        self.task = task
        let cfg = AppConfig.shared
        self.model = cfg.defaultModel
        self.systemPrompt = task.defaultSystemPrompt
        self.skills = Skill.bundled
    }

    func bind(to appState: AppState) {
        self.appState = appState
        if !appState.availableModels.contains(where: { $0.name == model }) {
            self.model = appState.recommendedModel(for: task.id)
        }
    }

    var availableModels: [OllamaModel] { appState?.availableModels ?? [] }
    var connectionOK: Bool { appState?.connectionOK ?? false }
    private var inferenceClient: (any InferenceClient)? { appState?.client }

    private var skillPromptAddendum: String {
        let active = skills.filter { enabledSkillIds.contains($0.id) }
        guard !active.isEmpty else { return "" }
        let header = "\n\nYou have the following Skills available; weave them into your reply when relevant:\n"
        return header + active.map { "- \($0.name): \($0.systemPromptAddendum)" }.joined(separator: "\n")
    }

    private var effectiveSystemPrompt: String {
        var s = systemPrompt
        if thinkingMode {
            s += "\n\nThink step-by-step before answering. Begin your reply with a brief <thinking>…</thinking> block, then give the final answer."
        }
        s += skillPromptAddendum
        return s
    }

    func clearChat() {
        messages.removeAll()
        attachedImages.removeAll()
        statusLine = "Conversation cleared."
    }

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachedImages.isEmpty, !isStreaming else { return }

        var userMsg = ChatMessage(role: .user, content: trimmed)
        userMsg.images = attachedImages.map { $0.base64EncodedString() }
        messages.append(userMsg)

        let pendingImages = attachedImages
        input = ""
        attachedImages.removeAll()

        messages.append(ChatMessage(role: .assistant, content: ""))
        let assistantIndex = messages.count - 1
        isStreaming = true
        lastTokensPerSec = nil
        statusLine = "Generating with \(model)…"

        var conversation: [ChatMessage] = [ChatMessage(role: .system, content: effectiveSystemPrompt)]
        conversation.append(contentsOf: messages.dropLast())
        // Replace last user message images with the pending ones
        if let lastUserIdx = conversation.lastIndex(where: { $0.role == .user }) {
            conversation[lastUserIdx].images = pendingImages.map { $0.base64EncodedString() }
        }

        guard let client = self.inferenceClient else {
            self.statusLine = "No inference client (engine offline)"
            self.isStreaming = false
            return
        }
        let model = self.model
        let temp = self.temperature
        let topP = self.topP
        let maxTok = self.maxTokens

        Task {
            do {
                try await client.streamChat(
                    model: model,
                    messages: conversation,
                    temperature: temp,
                    topP: topP,
                    maxTokens: maxTok,
                    onToken: { [weak self] token in
                        Task { @MainActor in
                            guard let self = self else { return }
                            guard self.messages.indices.contains(assistantIndex) else { return }
                            self.messages[assistantIndex].content += token
                        }
                    },
                    onStats: { [weak self] evalCount, totalNs in
                        Task { @MainActor in
                            guard let self = self else { return }
                            if let n = evalCount, let t = totalNs, t > 0 {
                                self.lastTokensPerSec = Double(n) / (Double(t) / 1_000_000_000.0)
                            }
                        }
                    }
                )
                await MainActor.run {
                    self.isStreaming = false
                    if let tps = self.lastTokensPerSec {
                        self.statusLine = String(format: "Done — %.1f tok/s on %@", tps, model)
                    } else {
                        self.statusLine = "Done."
                    }
                }
            } catch {
                await MainActor.run {
                    if self.messages.indices.contains(assistantIndex), self.messages[assistantIndex].content.isEmpty {
                        self.messages[assistantIndex].content = "⚠️ Error: \(error.localizedDescription)"
                    }
                    self.isStreaming = false
                    self.statusLine = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Single-turn (Prompt Lab) — discards prior history.
    func runOnce() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }
        messages.removeAll()
        send()
    }

    /// Trigger an image picker. On macOS this opens an NSOpenPanel; on iOS the
    /// view layer presents a SwiftUI `PhotosPicker` and feeds the resulting
    /// Data here via `attach(imageData:)`.
    @Published var showingImagePicker: Bool = false

    func openImagePicker() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .image]
        if panel.runModal() == .OK, let url = panel.url, let data = try? Data(contentsOf: url) {
            attachedImages.append(data)
        }
        #else
        showingImagePicker = true
        #endif
    }

    func attach(imageData: Data) {
        attachedImages.append(imageData)
    }
}
