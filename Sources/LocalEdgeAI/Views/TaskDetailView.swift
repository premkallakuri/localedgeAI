import SwiftUI

/// Mirrors Android's `ModelList` task-detail landing: a centered hero (icon, big
/// title with task gradient, experimental pill, description, API/Example links,
/// "N models available"), then a "Recommended models" section with expand/collapse
/// model cards. Selecting a model's arrow opens the actual chat surface.
struct TaskDetailView: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @Environment(\.palette) private var palette
    @Environment(\.customColors) private var custom

    @State private var selectedModel: OllamaModel? = nil
    @State private var expandedModelId: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                modelsSection
                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background(taskBgTint)
        .navigationDestination(item: $selectedModel) { model in
            taskHostFor(model: model)
        }
        .task { await appState.refreshModels() }
    }

    private var taskBgTint: Color {
        // Android `getTaskBgColor` — pale tint based on task index. Use a barely-tinted surface.
        custom.taskBgGradients[colorIndex].first?.opacity(0.10) ?? palette.surface
    }

    private var colorIndex: Int {
        switch task.id {
        case .llmChat:           return 2
        case .llmAgentChat:      return 0
        case .llmHermesAgent:    return 0
        case .llmAskImage:       return 1
        case .llmAskAudio:       return 0
        case .llmPromptLab:      return 3
        case .llmMobileActions:  return 2
        case .llmTinyGarden:     return 1
        case .modelManager:      return 2
        case .benchmark:         return 3
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            TaskIconShape(task: task, width: 88)
                .padding(.top, 24)

            Text(task.label)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: custom.taskBgGradients[colorIndex],
                                   startPoint: .leading, endPoint: .trailing)
                )

            if task.experimental {
                Text("EXPERIMENTAL")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(custom.warningContainer))
                    .foregroundStyle(custom.warningText)
            } else if task.newBadge {
                Text("NEW")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(custom.newFeatureContainer))
                    .foregroundStyle(custom.newFeatureText)
            }

            Text(task.description)
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurface)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)
                .lineSpacing(2)

            HStack(spacing: 22) {
                comingSoonLink(systemImage: "doc.text", title: "API Documentation")
                comingSoonLink(systemImage: "chevron.left.forwardslash.chevron.right", title: "Example code")
            }
            .padding(.top, 2)

            Text("\(appState.availableModels.count) model(s) available")
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    /// Non-clickable doc/code label with a "Coming soon" subtitle.
    /// Replaces the old `Link` to external GitHub/HuggingFace pages — we no
    /// longer surface upstream Google AI Edge URLs anywhere in the app.
    private func comingSoonLink(systemImage: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text("coming soon")
                    .font(.system(size: 9))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
        }
        .foregroundStyle(palette.onSurfaceVariant)
        .opacity(0.65)
    }

    // MARK: - Models

    @ViewBuilder
    private var modelsSection: some View {
        if appState.availableModels.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text(appState.connectionOK ? "Loading models…" : appState.engineStatusLine)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended models")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.onSurface)
                    .padding(.leading, 4)
                    .padding(.top, 6)
                ForEach(Array(appState.availableModels.enumerated()), id: \.element.id) { idx, model in
                    ModelCard(
                        model: model,
                        bestOverall: idx == 0,
                        expanded: expandedModelId == model.id,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedModelId = (expandedModelId == model.id) ? nil : model.id
                            }
                        },
                        onEnter: {
                            selectedModel = model
                        }
                    )
                }
            }
        }
    }

    // MARK: - Navigation to chat / task surface

    @ViewBuilder
    private func taskHostFor(model: OllamaModel) -> some View {
        switch task.id {
        case .llmChat:           ChatScreen(task: task, initialModel: model.name)
        case .llmAgentChat:      AgentChatScreen(task: task, initialModel: model.name)
        case .llmHermesAgent:    HermesAgentScreen(task: task, initialModel: model.name)
        case .llmAskImage:       AskImageScreen(task: task, initialModel: model.name)
        case .llmAskAudio:       AudioScribeScreen(task: task)
        case .llmPromptLab:      PromptLabScreen(task: task, initialModel: model.name)
        case .llmMobileActions:  MobileActionsScreen(task: task, initialModel: model.name)
        case .llmTinyGarden:     TinyGardenScreen(task: task, initialModel: model.name)
        case .modelManager:      ModelManagerScreen(task: task)
        case .benchmark:         BenchmarkScreen(task: task)
        }
    }
}

// MARK: - Model card

struct ModelCard: View {
    let model: OllamaModel
    let bestOverall: Bool
    let expanded: Bool
    let onToggle: () -> Void
    let onEnter: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.customColors) private var custom

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if bestOverall {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 13))
                            Text("Best overall")
                                .font(.system(size: 12))
                                .foregroundStyle(palette.onSurfaceVariant)
                        }
                    }
                    Text(model.name)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                    HStack(spacing: 6) {
                        Image(systemName: model.size == nil ? "questionmark.circle" : "arrow.down.circle.fill")
                            .foregroundStyle(model.size == nil ? palette.onSurfaceVariant : custom.linkColor)
                            .font(.system(size: 13))
                        Text(model.sizeGB).font(.system(size: 12)).foregroundStyle(palette.onSurfaceVariant)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .foregroundStyle(palette.onSurfaceVariant)
                            .font(.system(size: 12))
                        Text("Model details · coming soon")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                    }
                    .opacity(0.65)
                }
                Spacer()
                VStack(spacing: 6) {
                    Button {} label: {
                        Image(systemName: "ellipsis").font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                    .opacity(bestOverall ? 1 : 0)
                    Button(action: onToggle) {
                        Image(systemName: expanded ? "chevron.up" : (bestOverall ? "chevron.up" : "chevron.down"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.onSurfaceVariant)
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded || bestOverall {
                HStack {
                    Spacer()
                    Button(action: onEnter) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22).padding(.vertical, 12)
                            .background(Capsule().fill(custom.linkColor))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.surfaceContainerLowest))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.outlineVariant.opacity(0.5)))
    }
}
