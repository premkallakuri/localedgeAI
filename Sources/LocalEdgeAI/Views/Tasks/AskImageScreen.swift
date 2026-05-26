import SwiftUI

struct AskImageScreen: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @StateObject private var session: ChatSessionViewModel

    let initialModel: String?
    init(task: GalleryTask, initialModel: String? = nil) {
        self.task = task
        self.initialModel = initialModel
        let s = ChatSessionViewModel(task: task)
        if let m = initialModel { s.model = m }
        _session = StateObject(wrappedValue: s)
    }

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            ChatPanel(session: session, showImageAttach: true, showThinkingToggle: false)
        }
        .onAppear {
            session.bind(to: appState)
            if !appState.visionCapableModels.contains(session.model),
               let vis = appState.availableModels.first(where: { appState.visionCapableModels.contains($0.name) }) {
                session.model = vis.name
            }
        }
    }
}
