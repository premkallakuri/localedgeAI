import Foundation

#if os(iOS) || os(visionOS)
import CLiteRTLM

/// Thin Swift wrapper around CLiteRTLM (Google AI Edge LiteRT-LM C API).
///
/// Mirrors `InferenceClient` so SwiftUI views can swap engines without caring.
/// Loads a `.litertlm` / `.task` model from `modelPath`, opens a conversation,
/// and streams chunks back via callbacks (the same shape llama.cpp uses).
actor LiteRtLmClient: InferenceClient {

    enum E: Error, LocalizedError {
        case modelNotFound(String)
        case engineCreateFailed
        case sessionCreateFailed
        case conversationCreateFailed
        case sendFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .modelNotFound(let p):     return "LiteRT-LM model not found at \(p). Drop a .litertlm or .task file there and retry."
            case .engineCreateFailed:       return "litert_lm_engine_create returned NULL."
            case .sessionCreateFailed:      return "litert_lm_engine_create_session returned NULL."
            case .conversationCreateFailed: return "litert_lm_conversation_create returned NULL."
            case .sendFailed(let code):     return "litert_lm_conversation_send_message_stream failed with code \(code)."
            }
        }
    }

    // CLiteRTLM bridges every typedef'd opaque struct (LiteRtLmEngine,
    // LiteRtLmSession, LiteRtLmConversation, …) to Swift as `OpaquePointer?`.
    private var engine: OpaquePointer?
    private var session: OpaquePointer?
    private let modelPath: String
    private let backend: String

    /// Pick a search path for .litertlm / .task models. iOS apps usually store
    /// them under the app's Documents directory; the user can side-load via
    /// AirDrop / Files / Xcode.
    static let defaultModelDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("LocalEdge/models", isDirectory: true)
    }()

    init(modelDirectory: URL? = nil, backend: String = "cpu") {
        let dir = modelDirectory ?? Self.defaultModelDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Choose the first .litertlm or .task file we find in the directory.
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir,
                    includingPropertiesForKeys: nil))?
                    .filter { $0.pathExtension == "litertlm" || $0.pathExtension == "task" }
                    ?? []
        self.modelPath = urls.first?.path ?? dir.appendingPathComponent("gemma3-1b-it-int4.litertlm").path
        self.backend = backend
    }

    // MARK: - Engine lifecycle

    private func ensureEngine() throws {
        if engine != nil { return }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw E.modelNotFound(modelPath)
        }
        let settings = modelPath.withCString { mp in
            backend.withCString { be in
                litert_lm_engine_settings_create(mp, be, nil, nil)
            }
        }
        guard let s = settings else { throw E.engineCreateFailed }
        defer { litert_lm_engine_settings_delete(s) }

        guard let e = litert_lm_engine_create(s) else {
            throw E.engineCreateFailed
        }
        self.engine = e
    }

    deinit {
        if let s = session { litert_lm_session_delete(s) }
        if let e = engine  { litert_lm_engine_delete(e) }
    }

    /// Gemini-style Content JSON: { "parts": [{"text": "…"}], "role": "user|model" }.
    private static func contentJSON(role: String, text: String) -> String {
        let obj: [String: Any] = [
            "parts": [["text": text]],
            "role": role
        ]
        if let data = try? JSONSerialization.data(withJSONObject: obj),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{\"parts\":[{\"text\":\"\"}],\"role\":\"\(role)\"}"
    }

    // MARK: - InferenceClient

    func listModels() async throws -> [OllamaModel] {
        // Treat every .litertlm/.task file in the models directory as a "model".
        let dir = URL(fileURLWithPath: modelPath).deletingLastPathComponent()
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir,
                    includingPropertiesForKeys: [.fileSizeKey]))?
                    .filter { $0.pathExtension == "litertlm" || $0.pathExtension == "task" }
                    ?? []
        return urls.map { url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                .map { Int64($0) }
            return OllamaModel(name: url.lastPathComponent, size: size)
        }
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
        try ensureEngine()
        guard let engine = engine else { throw E.engineCreateFailed }

        // Build a session config with our sampler params + max tokens.
        guard let sessionCfg = litert_lm_session_config_create() else {
            throw E.sessionCreateFailed
        }
        defer { litert_lm_session_config_delete(sessionCfg) }
        litert_lm_session_config_set_max_output_tokens(sessionCfg, Int32(maxTokens))
        var samplerParams = LiteRtLmSamplerParams(
            type: kLiteRtLmSamplerTypeTopP,
            top_k: 64,
            top_p: Float(topP),
            temperature: Float(temperature),
            seed: 0
        )
        litert_lm_session_config_set_sampler_params(sessionCfg, &samplerParams)

        // Conversation: system message + history. LiteRT-LM tracks turn state internally.
        guard let convCfg = litert_lm_conversation_config_create() else {
            throw E.conversationCreateFailed
        }
        defer { litert_lm_conversation_config_delete(convCfg) }
        litert_lm_conversation_config_set_session_config(convCfg, sessionCfg)

        // LiteRT-LM expects messages encoded as Gemini-style Content JSON,
        // e.g. {"parts":[{"text":"…"}],"role":"user"}. Raw user text alone
        // makes send_message_stream return -1.
        if let sys = messages.first(where: { $0.role == .system })?.content, !sys.isEmpty {
            let json = Self.contentJSON(role: "user", text: sys)
            json.withCString { litert_lm_conversation_config_set_system_message(convCfg, $0) }
        }

        guard let conv = litert_lm_conversation_create(engine, convCfg) else {
            throw E.conversationCreateFailed
        }
        defer { litert_lm_conversation_delete(conv) }

        // Replay prior user/assistant messages so the model sees history.
        // We use the non-streaming `send_message` for replay turns; the final
        // user turn streams below so we can pipe deltas back to SwiftUI.
        for m in messages.dropLast() where m.role != .system {
            m.content.withCString { content in
                if let r = litert_lm_conversation_send_message(conv, content, nil, nil) {
                    litert_lm_json_response_delete(r)
                }
            }
        }

        guard let lastUser = messages.last(where: { $0.role == .user })?.content else {
            return
        }

        // Streaming callback bridge — wraps the Swift closure as a C function ptr.
        final class Box { var onToken: (String) -> Void; init(_ f: @escaping (String) -> Void) { self.onToken = f } }
        let box = Box(onToken)
        let unmanaged = Unmanaged.passRetained(box)
        defer { unmanaged.release() }

        let callback: LiteRtLmStreamCallback = { ctx, chunkPtr, _isFinal, _errPtr in
            guard let ctx = ctx, let chunkPtr = chunkPtr else { return }
            let boxed = Unmanaged<Box>.fromOpaque(ctx).takeUnretainedValue()
            boxed.onToken(String(cString: chunkPtr))
        }

        let started = DispatchTime.now().uptimeNanoseconds
        let messageJSON = Self.contentJSON(role: "user", text: lastUser)
        let rc = messageJSON.withCString { content in
            litert_lm_conversation_send_message_stream(
                conv, content,
                /*extra_context=*/ nil,
                /*optional_args=*/ nil,
                callback, unmanaged.toOpaque()
            )
        }
        if rc != 0 { throw E.sendFailed(rc) }

        // Pull stats from the conversation's benchmark info.
        if let bm = litert_lm_conversation_get_benchmark_info(conv) {
            defer { litert_lm_benchmark_info_delete(bm) }
            let decodeCount = litert_lm_benchmark_info_get_decode_token_count_at(bm, 0)
            let ended = DispatchTime.now().uptimeNanoseconds
            onStats(Int(decodeCount), Int64(ended &- started))
        } else {
            onStats(nil, nil)
        }
    }

    func generateOnce(model: String, prompt: String, maxTokens: Int) async throws
        -> (text: String, evalCount: Int?, totalNs: Int64?) {
        var collected = ""
        var count: Int? = nil
        var ns: Int64? = nil
        try await streamChat(
            model: model,
            messages: [ChatMessage(role: .user, content: prompt)],
            temperature: 0.2, topP: 0.95, maxTokens: maxTokens,
            onToken: { collected += $0 },
            onStats: { c, t in count = c; ns = t }
        )
        return (collected, count, ns)
    }
}

#else
// macOS / non-iOS: keep a stub so AppState compiles uniformly.

actor LiteRtLmClient: InferenceClient {
    enum E: Error, LocalizedError {
        case notAvailableOnMacOS
        var errorDescription: String? {
            "LiteRT-LM v0.12.0 ships ios-arm64 slices only in CLiteRTLM.xcframework — no macOS slice yet. On macOS use the llama.cpp engine."
        }
    }
    func listModels() async throws -> [OllamaModel] { throw E.notAvailableOnMacOS }
    func streamChat(model: String, messages: [ChatMessage], temperature: Double, topP: Double, maxTokens: Int,
                    onToken: @escaping (String) -> Void, onStats: @escaping (Int?, Int64?) -> Void) async throws {
        throw E.notAvailableOnMacOS
    }
    func generateOnce(model: String, prompt: String, maxTokens: Int) async throws
        -> (text: String, evalCount: Int?, totalNs: Int64?) {
        throw E.notAvailableOnMacOS
    }
}
#endif
