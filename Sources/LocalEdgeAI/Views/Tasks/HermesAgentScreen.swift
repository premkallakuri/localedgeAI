import SwiftUI

/// Hermes Agent: a small reference autonomous agent.
///
/// Goal of this file as a *teaching* artifact for new agents in this app:
///
///   1. Subclass the existing `ChatScreen` pattern — one SwiftUI view + one
///      `ChatSessionViewModel`.
///   2. Inject a structured system prompt that defines the agent's loop
///      (here: PLAN → EXECUTE → REFLECT).
///   3. Surface example prompts in a sidebar so the user can taste the
///      agent's capability in one tap.
///   4. Keep the chat plumbing identical — `ChatPanel` handles the streaming,
///      markdown, image attach, model picker, status bar, etc.
///
/// Copy this file to `Views/Tasks/<YourAgent>Screen.swift`, change the system
/// prompt + example prompts + system-tile in `GalleryTask.allTasks`, register
/// it in `TaskDetailView.taskHostFor(model:)`, and you have a new agent.
struct HermesAgentScreen: View {
    let task: GalleryTask
    let initialModel: String?
    @EnvironmentObject var appState: AppState
    @StateObject private var session: ChatSessionViewModel
    @Environment(\.palette) private var palette

    init(task: GalleryTask, initialModel: String? = nil) {
        self.task = task
        self.initialModel = initialModel
        let s = ChatSessionViewModel(task: task)
        if let m = initialModel { s.model = m }
        _session = StateObject(wrappedValue: s)
    }

    /// Example goals — one tap to load into the composer. These prompts are
    /// designed to exercise the PLAN/EXECUTE/REFLECT loop.
    private let exampleGoals: [(String, String, String)] = [
        ("Trip plan",     "airplane.departure",    "Plan a 3-day food-focused trip to Lisbon for one person on a $700 budget."),
        ("Code review",   "checkmark.shield",      "Code review: explain how to refactor a 400-line Swift view into smaller components."),
        ("Research",      "book",                  "Research: explain the key difference between LoRA and full fine-tuning, with one citation."),
        ("Daily plan",    "calendar.badge.clock",  "Plan my Saturday: gym, grocery, finish report draft, dinner with friends."),
        ("Decision tree", "arrow.triangle.branch", "I'm deciding between a MacBook Air and Pro for ML work. Lay out criteria and a recommendation."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            AdaptiveSplit {
                examplesSidebar
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                ChatPanel(session: session, showImageAttach: false, showThinkingToggle: true)
                    .frame(minWidth: 380)
            }
        }
        .onAppear { session.bind(to: appState) }
    }

    private var examplesSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("EXAMPLE GOALS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.onSurfaceVariant)
                Text("Tap a goal to load it into the composer, then send.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onSurfaceVariant)

                ForEach(exampleGoals, id: \.0) { name, icon, prompt in
                    Button {
                        session.input = prompt
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: icon)
                                .foregroundStyle(task.tint)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name).font(.system(size: 12, weight: .semibold))
                                Text(prompt)
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.onSurfaceVariant)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(palette.surfaceContainer))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(14)
        }
        .background(palette.surfaceContainerLow)
    }
}
