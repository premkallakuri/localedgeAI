import Foundation

struct AppConfig: Decodable {
    let appName: String
    let version: String
    let tagline: String
    let ollamaBaseURL: String
    let defaultModel: String
    let fallbackModels: [String]
    let systemPrompt: String
    let author: String

    var copyright: String { "© Prem Saran Kallakuri" }

    static let shared: AppConfig = {
        guard
            let url = Bundle.module.url(forResource: "AppConfig", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let cfg = try? JSONDecoder().decode(AppConfig.self, from: data)
        else {
            return AppConfig(
                appName: "LocalEdge AI",
                version: "0.4.0",
                tagline: "On-device generative AI for Mac & iOS",
                ollamaBaseURL: "http://127.0.0.1:11434",
                defaultModel: "gemma4:e4b",
                fallbackModels: ["gemma4:e2b", "gemma3:4b", "llama3.2:3b"],
                systemPrompt: "You are LocalEdge, a helpful on-device AI assistant.",
                author: "Prem Saran Kallakuri"
            )
        }
        return cfg
    }()
}
