import SwiftUI

struct RootView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTask: GalleryTask?

    // Default to light theme — matches the Android app's default presentation.
    private let palette: GalleryPalette = .light
    private let custom: GalleryCustomColors = .light

    var body: some View {
        NavigationStack {
            HomeView(selectedTask: $selectedTask)
                .navigationDestination(item: $selectedTask) { task in
                    TaskDetailView(task: task)
                }
        }
        .environmentObject(appState)
        .environment(\.palette, palette)
        .environment(\.customColors, custom)
        .background(palette.surfaceContainer)
        .preferredColorScheme(.light)
        .task {
            #if os(macOS)
            await LlamaServerManager.shared.ensureRunning()
            #endif
            await appState.refreshModels()
        }
        .tint(custom.appTitleGradient.last ?? palette.primary)
    }
}

struct TaskHostView: View {
    let task: GalleryTask
    @Environment(\.palette) private var palette

    var body: some View {
        Group {
            switch task.id {
            case .llmChat:          ChatScreen(task: task)
            case .llmAgentChat:     AgentChatScreen(task: task)
            case .llmHermesAgent:   HermesAgentScreen(task: task)
            case .llmAskImage:      AskImageScreen(task: task)
            case .llmAskAudio:      AudioScribeScreen(task: task)
            case .llmPromptLab:     PromptLabScreen(task: task)
            case .llmMobileActions: MobileActionsScreen(task: task)
            case .llmTinyGarden:    TinyGardenScreen(task: task)
            case .modelManager:     ModelManagerScreen(task: task)
            case .benchmark:        BenchmarkScreen(task: task)
            }
        }
        .background(palette.background)
        .navigationTitle(task.label)
    }
}

/// Common chrome shared by all task screens: header with icon, label, description.
struct TaskHeader: View {
    let task: GalleryTask
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(task.tint.opacity(0.18))
                    Image(systemName: task.iconName).font(.system(size: 22)).foregroundStyle(task.tint)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(task.label)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.onSurface)
                        if task.newBadge {
                            badge("NEW", bg: palette.primary, fg: palette.onPrimary)
                        } else if task.experimental {
                            badge("EXPERIMENTAL", bg: palette.tertiaryContainer, fg: palette.tertiary)
                        }
                    }
                    Text(task.description)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            Divider().background(palette.outlineVariant)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func badge(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }
}
