import SwiftUI

struct ChatScreen: View {
    let task: GalleryTask
    let initialModel: String?
    @EnvironmentObject var appState: AppState
    @StateObject private var session: ChatSessionViewModel

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
            ChatPanel(session: session, showImageAttach: false, showThinkingToggle: true)
        }
        .onAppear { session.bind(to: appState) }
    }
}
