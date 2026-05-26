import Foundation

/// Mirrors the skill manifest from /skills/built-in/<name>/SKILL.md frontmatter,
/// simplified to a JSON-friendly shape for the macOS port.
struct Skill: Identifiable, Hashable, Codable {
    var id: String        // e.g. "query-wikipedia"
    var name: String      // human label
    var category: String  // "built-in" | "featured" | "community"
    var description: String
    var icon: String      // SF Symbol
    var systemPromptAddendum: String  // appended to the system prompt when enabled

    static let bundled: [Skill] = [
        Skill(
            id: "query-wikipedia",
            name: "Query Wikipedia",
            category: "built-in",
            description: "Look up factual context from Wikipedia to ground your answers.",
            icon: "book.closed.fill",
            systemPromptAddendum: "When the user asks a factual question, briefly cite likely Wikipedia entries and the key facts you would retrieve from them."
        ),
        Skill(
            id: "interactive-map",
            name: "Interactive Map",
            category: "built-in",
            description: "Show locations and routes inline.",
            icon: "map.fill",
            systemPromptAddendum: "When the user asks about places, list 3–5 named POIs with rough coordinates."
        ),
        Skill(
            id: "calculate-hash",
            name: "Calculate Hash",
            category: "built-in",
            description: "Compute SHA/MD5 hashes of input text.",
            icon: "lock.shield.fill",
            systemPromptAddendum: "If the user provides text and asks for a hash, explain how SHA-256 / MD5 are computed and offer to compute one."
        ),
        Skill(
            id: "qr-code",
            name: "QR Code",
            category: "built-in",
            description: "Describe how to encode text or URLs as a QR code.",
            icon: "qrcode",
            systemPromptAddendum: "When asked, describe how to generate a QR code for the given text and what apps can do it natively on macOS."
        ),
        Skill(
            id: "kitchen-adventure",
            name: "Kitchen Adventure",
            category: "built-in",
            description: "Turn ingredients into a step-by-step recipe.",
            icon: "fork.knife",
            systemPromptAddendum: "When the user lists ingredients, propose a single coherent recipe with steps and timing."
        ),
        Skill(
            id: "mood-tracker",
            name: "Mood Tracker",
            category: "built-in",
            description: "Reflect on the user's mood and suggest one small step.",
            icon: "heart.text.square.fill",
            systemPromptAddendum: "When the user shares how they feel, reflect it back briefly and suggest one tiny supportive action."
        ),
        Skill(
            id: "send-email",
            name: "Draft Email",
            category: "built-in",
            description: "Draft a polished email from a quick brief.",
            icon: "envelope.fill",
            systemPromptAddendum: "When asked to write an email, produce subject + body. Match the requested tone."
        ),
        Skill(
            id: "text-spinner",
            name: "Text Spinner",
            category: "built-in",
            description: "Rephrase or vary text on demand.",
            icon: "text.alignleft",
            systemPromptAddendum: "When asked to rephrase, produce 3 distinct variations differing in tone."
        ),
        Skill(
            id: "restaurant-roulette",
            name: "Restaurant Roulette",
            category: "featured",
            description: "Suggest a random restaurant style for tonight.",
            icon: "die.face.5.fill",
            systemPromptAddendum: "When asked for dinner ideas, pick one cuisine + a dish to anchor the suggestion."
        ),
        Skill(
            id: "mood-music",
            name: "Mood Music",
            category: "featured",
            description: "Recommend a song to match the moment.",
            icon: "music.note",
            systemPromptAddendum: "Recommend one specific song with artist that matches the user's described mood."
        ),
        Skill(
            id: "virtual-piano",
            name: "Virtual Piano",
            category: "featured",
            description: "Describe simple piano sequences.",
            icon: "pianokeys",
            systemPromptAddendum: "When asked, output ASCII piano notation or describe note sequences in a simple format."
        ),
    ]
}
