import SwiftUI

/// Mirrors Android `TinyGardenTask`: 3×3 grid (plots 1–9), 4 seed types,
/// FunctionGemma-style structured action prompts.
struct TinyGardenScreen: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @StateObject private var session: ChatSessionViewModel
    @Environment(\.palette) private var palette
    @Environment(\.customColors) private var custom

    /// 9 plots — emoji representing current state (empty, planted, watered, harvested).
    @State private var plots: [String] = Array(repeating: "", count: 9)

    let initialModel: String?
    init(task: GalleryTask, initialModel: String? = nil) {
        self.task = task
        self.initialModel = initialModel
        let s = ChatSessionViewModel(task: task)
        s.systemPrompt = TinyGardenScreen.androidStyleSystemPrompt
        if let m = initialModel { s.model = m }
        _session = StateObject(wrappedValue: s)
    }

    /// Verbatim from Android `TinyGardenTask.SYSTEM_PROMPT`, plus a final
    /// "respond with one JSON line" instruction since we can't bind to a tool
    /// directly without the LiteRT-LM tool API on macOS yet.
    static let androidStyleSystemPrompt = """
    You are an assistant helping the user play a game about gardening.

    The environment is a 3x3 grid of garden plots. The plots are numbered 1 through 9.

    Garden Plot Layout:
    - Row 1: Plots 1, 2, 3 (top row)
    - Row 2: Plots 4, 5, 6 (middle row)
    - Row 3: Plots 7, 8, 9 (bottom row)

    Help the user plant seeds, water plots, and harvest flowers.

    There are 4 kinds of seeds you can plant:
    1. sunflower
    2. daisy
    3. rose
    4. special (edge gallery, special, secret)

    Tips:
    - "top row" has plots 1, 2, 3.
    - "middle row" has plots 4, 5, 6.
    - "bottom row" has plots 7, 8, 9.
    - "left column" has plots 1, 4, 7.
    - "middle column" has plots 2, 5, 8.
    - "right column" has plots 3, 6, 9.

    Respond with EXACTLY ONE JSON object on the first line:
    {"action":"plant|water|harvest","seed":"sunflower|daisy|rose|special|null","plots":[<int 1-9>, ...],"note":"<one sentence>"}
    Then a one-line natural-language confirmation on the second line.
    """

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            AdaptiveSplit {
                gardenPanel
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                ChatPanel(session: session, showImageAttach: false)
                    .frame(minWidth: 380)
            }
        }
        .onAppear { session.bind(to: appState) }
        .onChange(of: session.messages.last?.content) { newContent in
            guard let c = newContent else { return }
            applyAction(from: c)
        }
    }

    // MARK: - Garden panel

    private var gardenPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Garden")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.onSurface)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<9) { i in
                    plotTile(index: i)
                }
            }
            .padding(.bottom, 6)

            // Legend
            HStack(spacing: 16) {
                legend(emoji: "🌻", label: "sunflower")
                legend(emoji: "🌼", label: "daisy")
                legend(emoji: "🌹", label: "rose")
                legend(emoji: "✨", label: "special")
            }
            .font(.system(size: 11))

            HStack(spacing: 8) {
                Button {
                    plots = Array(repeating: "", count: 9)
                    session.clearChat()
                } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                .buttonStyle(.bordered)

                Button {
                    session.input = "Plant sunflowers in the top row"
                } label: { Text("Try: plant sunflowers in top row").font(.system(size: 11)) }
                .buttonStyle(.borderless)
            }

            Spacer()
        }
        .padding(16)
        .background(palette.surfaceContainerLow)
    }

    private func plotTile(index i: Int) -> some View {
        let emoji = plots[i]
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(custom.taskBgGradients[1][0].opacity(0.10))   // green-ish
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(custom.taskBgGradients[1][1].opacity(0.40), style: StrokeStyle(lineWidth: 1, dash: [4,3]))
                )
            VStack(alignment: .leading) {
                Text("\(i + 1)").font(.system(size: 10, weight: .bold)).foregroundStyle(palette.onSurfaceVariant).padding(6)
                Spacer()
                Text(emoji).font(.system(size: 34))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 6)
        }
        .frame(height: 80)
    }

    private func legend(emoji: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji)
            Text(label).foregroundStyle(palette.onSurfaceVariant)
        }
    }

    // MARK: - Apply action from model output

    private struct ParsedAction: Decodable {
        let action: String
        let seed: String?
        let plots: [Int]
        let note: String?
    }

    private func applyAction(from text: String) {
        // Find the first JSON object in the message — handles bare lines and
        // markdown code-fenced blocks (```json … ```), since FunctionGemma-style
        // outputs sometimes wrap the structured response.
        let nsText = text as NSString
        guard
            let regex = try? NSRegularExpression(pattern: #"\{[\s\S]*?\}"#, options: []),
            let m = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        else { return }
        let jsonString = nsText.substring(with: m.range)
        guard let data = jsonString.data(using: .utf8) else { return }
        guard let p = try? JSONDecoder().decode(ParsedAction.self, from: data) else { return }

        let glyph: String = {
            switch (p.action, p.seed?.lowercased()) {
            case ("plant", "sunflower"): return "🌻"
            case ("plant", "daisy"):     return "🌼"
            case ("plant", "rose"):      return "🌹"
            case ("plant", "special"):   return "✨"
            case ("plant", _):           return "🌱"
            case ("water", _):           return "💧"
            case ("harvest", _):         return "🧺"
            default:                     return ""
            }
        }()

        for n in p.plots {
            let idx = n - 1
            if idx >= 0 && idx < plots.count {
                if p.action == "harvest" {
                    plots[idx] = ""
                } else {
                    plots[idx] = glyph
                }
            }
        }
    }
}
