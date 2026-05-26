import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case system, user, assistant }
    var id = UUID()
    var role: Role
    var content: String
    var images: [String]? = nil   // base64-encoded image data
}

struct OllamaModel: Identifiable, Hashable, Decodable {
    let name: String
    let size: Int64?
    var id: String { name }

    var sizeGB: String {
        guard let size = size else { return "—" }
        return String(format: "%.1f GB", Double(size) / 1_073_741_824.0)
    }
}

private struct TagsResponse: Decodable {
    struct Entry: Decodable { let name: String; let size: Int64? }
    let models: [Entry]
}

private struct ChatRequest: Encodable {
    struct Msg: Encodable {
        let role: String
        let content: String
        let images: [String]?
    }
    let model: String
    let messages: [Msg]
    let stream: Bool
    let options: [String: AnyEncodable]?
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private struct ChatChunk: Decodable {
    struct Msg: Decodable { let role: String?; let content: String? }
    let message: Msg?
    let done: Bool?
    let total_duration: Int64?
    let eval_count: Int?
}

actor OllamaClient {
    let baseURL: URL

    init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!
    }

    func listModels() async throws -> [OllamaModel] {
        let url = baseURL.appendingPathComponent("api/tags")
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        let (data, _) = try await URLSession.shared.data(for: req)
        let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
        return decoded.models.map { OllamaModel(name: $0.name, size: $0.size) }
    }

    func streamChat(
        model: String,
        messages: [ChatMessage],
        temperature: Double = 0.7,
        topP: Double = 0.95,
        maxTokens: Int = 1024,
        onToken: @escaping (String) -> Void,
        onStats: @escaping (_ evalCount: Int?, _ totalNs: Int64?) -> Void
    ) async throws {
        let url = baseURL.appendingPathComponent("api/chat")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600

        let opts: [String: AnyEncodable] = [
            "temperature": AnyEncodable(value: temperature),
            "top_p": AnyEncodable(value: topP),
            "num_predict": AnyEncodable(value: maxTokens)
        ]

        let payload = ChatRequest(
            model: model,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content, images: $0.images) },
            stream: true,
            options: opts
        )
        req.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "Ollama", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Ollama returned HTTP \(http.statusCode)"])
        }

        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8) else { continue }
            guard let chunk = try? decoder.decode(ChatChunk.self, from: data) else { continue }
            if let token = chunk.message?.content, !token.isEmpty {
                onToken(token)
            }
            if chunk.done == true {
                onStats(chunk.eval_count, chunk.total_duration)
                break
            }
        }
    }

    /// Run a single prompt to completion (non-streaming) for benchmarking.
    func generateOnce(model: String, prompt: String, maxTokens: Int = 256) async throws -> (text: String, evalCount: Int?, totalNs: Int64?) {
        let url = baseURL.appendingPathComponent("api/chat")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600

        let payload = ChatRequest(
            model: model,
            messages: [.init(role: "user", content: prompt, images: nil)],
            stream: false,
            options: ["num_predict": AnyEncodable(value: maxTokens),
                      "temperature": AnyEncodable(value: 0.2)]
        )
        req.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await URLSession.shared.data(for: req)
        struct OneShot: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg?
            let eval_count: Int?
            let total_duration: Int64?
        }
        let one = try JSONDecoder().decode(OneShot.self, from: data)
        return (one.message?.content ?? "", one.eval_count, one.total_duration)
    }
}
