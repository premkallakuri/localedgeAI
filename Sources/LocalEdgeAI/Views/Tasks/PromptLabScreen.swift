import SwiftUI

struct PromptLabScreen: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @StateObject private var session: ChatSessionViewModel
    @Environment(\.palette) private var palette

    let initialModel: String?
    init(task: GalleryTask, initialModel: String? = nil) {
        self.task = task
        self.initialModel = initialModel
        let s = ChatSessionViewModel(task: task)
        if let m = initialModel { s.model = m }
        _session = StateObject(wrappedValue: s)
    }

    private let templates: [(String, String)] = [
        ("Summarize",  "Summarize the following text in 3 bullet points:\n\n"),
        ("Rephrase",   "Rephrase the following with a friendlier tone:\n\n"),
        ("Code review","Review the following code for bugs and style issues:\n\n"),
        ("Brainstorm", "Generate 5 creative ideas about: "),
        ("Translate",  "Translate the following to Spanish:\n\n"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            AdaptiveSplit {
                paramSidebar
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                ChatPanel(session: session, showImageAttach: false, showThinkingToggle: false)
                    .frame(minWidth: 380)
            }
        }
        .onAppear { session.bind(to: appState) }
    }

    private var paramSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Templates") {
                    VStack(spacing: 6) {
                        ForEach(templates, id: \.0) { name, body in
                            Button {
                                session.input = body
                            } label: {
                                HStack {
                                    Text(name).font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .font(.system(size: 10))
                                        .foregroundStyle(palette.onSurfaceVariant)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surfaceContainer))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                section("Sampling") {
                    VStack(alignment: .leading, spacing: 10) {
                        sliderRow("Temperature", value: $session.temperature, range: 0...2, format: "%.2f")
                        sliderRow("Top P", value: $session.topP, range: 0...1, format: "%.2f")
                        HStack {
                            Text("Max tokens").font(.system(size: 11))
                            Spacer()
                            Stepper(value: $session.maxTokens, in: 64...4096, step: 64) {
                                Text("\(session.maxTokens)").font(.system(size: 11).monospacedDigit())
                            }
                            .labelsHidden()
                        }
                    }
                }

                section("System prompt") {
                    TextEditor(text: $session.systemPrompt)
                        .font(.system(size: 11))
                        .frame(minHeight: 80, maxHeight: 140)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(palette.surfaceContainerLowest))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.outlineVariant))
                }
            }
            .padding(14)
        }
        .background(palette.surfaceContainerLow)
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 11))
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            Slider(value: value, in: range)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.onSurfaceVariant)
            content()
        }
    }
}
