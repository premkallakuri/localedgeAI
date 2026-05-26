import Foundation

/// Identifies the inference runtime backing this app.
///
/// Mirrors the runtime contract Android's gallery uses internally (LiteRT-LM via
/// `com.google.ai.edge.litertlm`). On macOS today, LiteRT-LM is iOS-only at
/// v0.12.0 (the CLiteRTLM xcframework ships ios-arm64 slices only), so we ship
/// llama.cpp's `llama-server` as the default macOS runtime. It runs the same
/// Gemma weights — only the container format differs (.gguf vs .litertlm).
enum InferenceEngine: String, CaseIterable, Identifiable {
    /// llama.cpp / `llama-server` on localhost (default; ships with Homebrew).
    case llamaCpp = "llama.cpp"
    /// Ollama daemon (uses a llama.cpp fork under the hood).
    case ollama = "ollama"
    /// Google AI Edge LiteRT-LM. iOS-only at v0.12.0 — placeholder for when the
    /// macOS slice ships in `CLiteRTLM.xcframework`.
    case liteRTLM = "LiteRT-LM"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var subtitle: String {
        switch self {
        case .llamaCpp:  return "Direct llama.cpp · Metal · same Gemma weights"
        case .ollama:    return "llama.cpp fork · model store · daemonized"
        case .liteRTLM:  return "Google AI Edge · iOS-only at v0.12.0 (macOS pending)"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .llamaCpp:  return "http://127.0.0.1:8088"
        case .ollama:    return "http://127.0.0.1:11434"
        case .liteRTLM:  return ""
        }
    }

    var available: Bool {
        switch self {
        case .liteRTLM:
            #if os(iOS) || os(visionOS)
            return true       // Native LiteRT-LM via CLiteRTLM.xcframework
            #else
            return false      // No macOS slice in v0.12.0
            #endif
        default:
            return true
        }
    }
}

/// Common surface every inference client exposes — keeps the SwiftUI layer engine-agnostic.
protocol InferenceClient: Sendable {
    func listModels() async throws -> [OllamaModel]
    func streamChat(
        model: String,
        messages: [ChatMessage],
        temperature: Double,
        topP: Double,
        maxTokens: Int,
        onToken: @escaping (String) -> Void,
        onStats: @escaping (_ evalCount: Int?, _ totalNs: Int64?) -> Void
    ) async throws

    func generateOnce(model: String, prompt: String, maxTokens: Int) async throws
        -> (text: String, evalCount: Int?, totalNs: Int64?)
}

// MARK: - Ollama

extension OllamaClient: InferenceClient {}

// MARK: - llama-server (OpenAI-compatible /v1/chat/completions)

actor LlamaServerClient: InferenceClient {
    let baseURL: URL

    init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!
    }

    func listModels() async throws -> [OllamaModel] {
        // llama-server exposes both /v1/models (OpenAI-style) and /models (extended).
        let url = baseURL.appendingPathComponent("v1/models")
        var req = URLRequest(url: url); req.timeoutInterval = 4
        let (data, _) = try await URLSession.shared.data(for: req)
        struct R: Decodable {
            struct M: Decodable { let id: String? }
            let data: [M]?
        }
        if let r = try? JSONDecoder().decode(R.self, from: data), let ms = r.data {
            return ms.compactMap { $0.id }.map { OllamaModel(name: $0, size: nil) }
        }
        // Fallback: parse the /models endpoint
        struct Alt: Decodable {
            struct M: Decodable { let name: String? }
            let models: [M]?
        }
        if let a = try? JSONDecoder().decode(Alt.self, from: data), let ms = a.models {
            return ms.compactMap { $0.name }.map { OllamaModel(name: $0, size: nil) }
        }
        return []
    }

    func streamChat(
        model: String,
        messages: [ChatMessage],
        temperature: Double,
        topP: Double,
        maxTokens: Int,
        onToken: @escaping (String) -> Void,
        onStats: @escaping (_ evalCount: Int?, _ totalNs: Int64?) -> Void
    ) async throws {
        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600

        // OpenAI-compatible payload — images are passed as data URLs in user message content blocks
        struct Msg: Encodable {
            let role: String
            let content: ContentValue
            enum ContentValue: Encodable {
                case text(String)
                case multimodal([Part])
                struct Part: Encodable {
                    let type: String
                    let text: String?
                    let image_url: ImageURL?
                    struct ImageURL: Encodable { let url: String }
                }
                func encode(to encoder: Encoder) throws {
                    var c = encoder.singleValueContainer()
                    switch self {
                    case .text(let s): try c.encode(s)
                    case .multimodal(let ps): try c.encode(ps)
                    }
                }
            }
        }

        let mappedMessages: [Msg] = messages.map { m in
            if let imgs = m.images, !imgs.isEmpty {
                var parts: [Msg.ContentValue.Part] = []
                if !m.content.isEmpty {
                    parts.append(.init(type: "text", text: m.content, image_url: nil))
                }
                for b64 in imgs {
                    parts.append(.init(type: "image_url", text: nil, image_url: .init(url: "data:image/png;base64,\(b64)")))
                }
                return Msg(role: m.role.rawValue, content: .multimodal(parts))
            } else {
                return Msg(role: m.role.rawValue, content: .text(m.content))
            }
        }

        struct Body: Encodable {
            let model: String
            let messages: [Msg]
            let stream: Bool
            let temperature: Double
            let top_p: Double
            let max_tokens: Int
            let stream_options: StreamOptions?
            struct StreamOptions: Encodable { let include_usage: Bool }
        }

        let body = Body(
            model: model,
            messages: mappedMessages,
            stream: true,
            temperature: temperature,
            top_p: topP,
            max_tokens: maxTokens,
            stream_options: .init(include_usage: true)
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LlamaServer", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "llama-server returned HTTP \(http.statusCode)"])
        }

        // SSE: each "data: <json>" line is one chunk; "data: [DONE]" terminates.
        let startTime = DispatchTime.now().uptimeNanoseconds
        var lastUsageTokens: Int? = nil
        var totalTokens = 0

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }

            struct Chunk: Decodable {
                struct Choice: Decodable {
                    struct Delta: Decodable { let content: String? }
                    let delta: Delta?
                    let finish_reason: String?
                }
                struct Usage: Decodable { let completion_tokens: Int? }
                let choices: [Choice]?
                let usage: Usage?
            }
            guard let chunk = try? JSONDecoder().decode(Chunk.self, from: data) else { continue }
            if let text = chunk.choices?.first?.delta?.content, !text.isEmpty {
                onToken(text)
                totalTokens += 1
            }
            if let u = chunk.usage?.completion_tokens { lastUsageTokens = u }
        }

        let endTime = DispatchTime.now().uptimeNanoseconds
        let totalNs = Int64(endTime &- startTime)
        let count = lastUsageTokens ?? totalTokens
        onStats(count, totalNs)
    }

    func generateOnce(model: String, prompt: String, maxTokens: Int = 256) async throws
        -> (text: String, evalCount: Int?, totalNs: Int64?) {
        var text = ""
        var count: Int? = nil
        var ns: Int64? = nil
        try await streamChat(
            model: model,
            messages: [ChatMessage(role: .user, content: prompt)],
            temperature: 0.2,
            topP: 0.95,
            maxTokens: maxTokens,
            onToken: { text += $0 },
            onStats: { c, t in count = c; ns = t }
        )
        return (text, count, ns)
    }
}

// LiteRtLmClient lives in Services/LiteRtLmClient.swift (real impl on iOS, stub on macOS).
