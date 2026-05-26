import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var availableModels: [OllamaModel] = []
    @Published var connectionOK: Bool = false
    @Published var defaultModel: String
    @Published var visionCapableModels: Set<String> = []
    @Published var engine: InferenceEngine = .llamaCpp
    @Published var engineStatusLine: String = ""

    private(set) var client: any InferenceClient
    let skills: [Skill] = Skill.bundled

    init() {
        let cfg = AppConfig.shared
        self.defaultModel = cfg.defaultModel
        // On iOS prefer native LiteRT-LM (matches the Android app's runtime).
        // On macOS default to llama.cpp (the LiteRT-LM xcframework is iOS-only at v0.12.0).
        #if os(iOS) || os(visionOS)
        self.engine = .liteRTLM
        self.client = LiteRtLmClient()
        #else
        self.engine = .llamaCpp
        self.client = LlamaServerClient(baseURL: InferenceEngine.llamaCpp.defaultBaseURL)
        #endif
    }

    func switchEngine(to engine: InferenceEngine) {
        self.engine = engine
        switch engine {
        case .llamaCpp:
            self.client = LlamaServerClient(baseURL: engine.defaultBaseURL)
        case .ollama:
            self.client = OllamaClient(baseURL: engine.defaultBaseURL)
        case .liteRTLM:
            #if os(iOS) || os(visionOS)
            self.client = LiteRtLmClient()
            #else
            self.client = LiteRtLmClient()  // stub returns "not available on macOS"
            #endif
        }
        Task { await refreshModels() }
    }

    func refreshModels() async {
        do {
            let models = try await client.listModels()
            self.availableModels = models
            self.connectionOK = !models.isEmpty
            self.visionCapableModels = Set(models
                .map(\.name)
                .filter { name in
                    let n = name.lowercased()
                    return n.contains("gemma3") || n.contains("llava") || n.contains("bakllava") ||
                           n.contains("moondream") || n.contains("gemma4") || n.contains("minicpm-v")
                })
            if !models.contains(where: { $0.name == defaultModel }) {
                if let fallback = AppConfig.shared.fallbackModels.first(where: { name in models.contains(where: { $0.name == name }) }) {
                    self.defaultModel = fallback
                } else if let first = models.first {
                    self.defaultModel = first.name
                }
            }
            self.engineStatusLine = "\(engine.displayName) · \(models.count) model(s)"

            // (Removed the launch-time LiteRT-LM smoke test — the iOS
            // simulator runs inference CPU-only and the watchdog killed the
            // process before generation completed. The user can verify
            // inference by tapping AI Chat and sending a prompt manually.)
        } catch {
            self.connectionOK = false
            self.availableModels = []
            self.engineStatusLine = "\(engine.displayName) offline — \(error.localizedDescription)"
        }
    }

    func recommendedModel(for task: BuiltInTaskId) -> String {
        switch task {
        case .llmAskImage:
            if let vis = availableModels.first(where: { visionCapableModels.contains($0.name) }) {
                return vis.name
            }
            return defaultModel
        case .llmMobileActions, .llmTinyGarden:
            if let small = availableModels.first(where: { $0.name.lowercased().contains("270m") || $0.name.lowercased().contains("e2b") }) {
                return small.name
            }
            return defaultModel
        default:
            return defaultModel
        }
    }
}
