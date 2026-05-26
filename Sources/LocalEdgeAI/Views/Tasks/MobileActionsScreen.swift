import SwiftUI

struct MobileActionsScreen: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @StateObject private var session: ChatSessionViewModel
    @Environment(\.palette) private var palette

    let initialModel: String?
    init(task: GalleryTask, initialModel: String? = nil) {
        self.task = task
        self.initialModel = initialModel
        let s = ChatSessionViewModel(task: task)
        s.systemPrompt = "You are LocalEdge Actions. When the user asks for a device or app action, emit a single JSON object on the first line in the form {\"action\":\"<verb>\",\"target\":\"<app or thing>\",\"args\":{...}} and then a one-line natural explanation. Available actions: openApp, sendMessage, createNote, setReminder, addCalendar, search."
        if let m = initialModel { s.model = m }
        _session = StateObject(wrappedValue: s)
    }

    private let demoActions: [(String, String, String)] = [
        ("Open Safari",     "safari",        "open Safari"),
        ("New Reminder",    "checklist",     "create a reminder to call mom tomorrow at 5pm"),
        ("Calendar event",  "calendar",      "schedule a 30-min meeting with Alex next Tuesday 2pm"),
        ("Send Message",    "message.fill",  "send a text to Alex: \"running 10 min late\""),
        ("Quick Note",      "note.text",     "save a note: idea for weekend road trip to Carmel"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            AdaptiveSplit {
                quickActions
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
                ChatPanel(session: session, showImageAttach: false)
                    .frame(minWidth: 380)
            }
        }
        .onAppear { session.bind(to: appState) }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK ACTIONS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.horizontal, 14).padding(.top, 12)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(demoActions, id: \.0) { (label, icon, prompt) in
                        Button {
                            session.input = prompt
                        } label: {
                            HStack {
                                Image(systemName: icon).foregroundStyle(task.tint).frame(width: 22)
                                Text(label).font(.system(size: 12))
                                Spacer()
                                Image(systemName: "arrow.up.left").font(.system(size: 10)).foregroundStyle(palette.onSurfaceVariant)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surfaceContainer))
                        }
                        .buttonStyle(.plain)
                    }
                }.padding(.horizontal, 12)
            }
        }
        .background(palette.surfaceContainerLow)
    }
}
