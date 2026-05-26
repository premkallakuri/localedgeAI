import SwiftUI

struct AgentChatScreen: View {
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

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            AdaptiveSplit {
                skillSidebar
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
                ChatPanel(session: session, showImageAttach: false, showThinkingToggle: true)
                    .frame(minWidth: 400)
            }
        }
        .onAppear { session.bind(to: appState) }
    }

    private var skillSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Skills")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onSurface)
                Spacer()
                Text("\(session.enabledSkillIds.count) enabled")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)

            Divider().background(palette.outlineVariant)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    skillGroup(title: "Built-in", category: "built-in")
                    skillGroup(title: "Featured", category: "featured")
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
        }
        .background(palette.surfaceContainerLow)
    }

    private func skillGroup(title: String, category: String) -> some View {
        let items = appState.skills.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.bottom, 2)
            ForEach(items) { skill in
                skillRow(skill)
            }
        }
    }

    private func skillRow(_ skill: Skill) -> some View {
        let on = session.enabledSkillIds.contains(skill.id)
        return Button {
            if on {
                session.enabledSkillIds.remove(skill.id)
            } else {
                session.enabledSkillIds.insert(skill.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: skill.icon)
                    .foregroundStyle(on ? palette.primary : palette.onSurfaceVariant)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name)
                        .font(.system(size: 12, weight: on ? .semibold : .regular))
                        .foregroundStyle(palette.onSurface)
                    Text(skill.description)
                        .font(.system(size: 10))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? palette.primary : palette.outline)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(on ? palette.primaryContainer.opacity(0.35) : Color.clear))
        }
        .buttonStyle(.plain)
    }
}
