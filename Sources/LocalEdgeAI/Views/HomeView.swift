import SwiftUI

struct HomeView: View {
    @Binding var selectedTask: GalleryTask?
    @EnvironmentObject var appState: AppState

    @Environment(\.palette) private var palette
    @Environment(\.customColors) private var custom

    private let categoryOrder: [GalleryCategory] = [.llm, .agents, .experimental, .library]
    @State private var selectedCategory: GalleryCategory = .llm
    @State private var showEngineMenu = false

    private var tasksInSelectedCategory: [GalleryTask] {
        GalleryTask.allTasks.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                hero
                categoryTabs
                taskGrid
                Spacer(minLength: 24)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.surfaceContainer)  // Android home uses surfaceContainer
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(LinearGradient(colors: custom.appTitleGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("LocalEdge")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.onSurface)
            Spacer()
            engineSelector
            statusPill
            Button {
                Task { await appState.refreshModels() }
            } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Refresh models")
        }
    }

    private var engineSelector: some View {
        Menu {
            ForEach(InferenceEngine.allCases) { eng in
                Button {
                    appState.switchEngine(to: eng)
                } label: {
                    HStack {
                        Text(eng.displayName)
                        if eng == appState.engine { Image(systemName: "checkmark") }
                    }
                }
                .disabled(!eng.available)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                Text(appState.engine.displayName)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down").font(.system(size: 8))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(palette.surfaceContainerHigh))
            .foregroundStyle(palette.onSurface)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(appState.engine.subtitle)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.connectionOK ? custom.successColor : palette.error)
                .frame(width: 8, height: 8)
            Text(appState.connectionOK ? "\(appState.availableModels.count) model(s)" : "offline")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(palette.surfaceContainerHigh))
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Two-line title with the Android-style blue gradient on "LocalEdge.".
            (
                Text("Explore a world of\namazing on-device models from ")
                    .foregroundColor(palette.onSurface)
                +
                Text("LocalEdge.")
                    .foregroundStyle(
                        LinearGradient(colors: custom.appTitleGradient, startPoint: .leading, endPoint: .trailing)
                    )
            )
            .font(.system(size: 44, weight: .medium))
            .lineSpacing(2)

            Text("Native macOS · fully offline · runs Gemma via \(appState.engine.displayName)")
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.top, 6)
        }
        .padding(.top, 4)
    }

    // MARK: - Category tabs

    private var categoryTabs: some View {
        HStack(spacing: 8) {
            ForEach(categoryOrder) { cat in
                let active = cat == selectedCategory
                Button {
                    selectedCategory = cat
                } label: {
                    Text(cat.label)
                        .font(.system(size: 13, weight: active ? .semibold : .regular))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(
                            Capsule().fill(active ? custom.tabHeaderBg : Color.clear)
                        )
                        .overlay(Capsule().stroke(active ? Color.clear : palette.outlineVariant, lineWidth: 1))
                        .foregroundStyle(active ? Color.white : palette.onSurfaceVariant)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Task grid

    private var taskGrid: some View {
        let cols = [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 16, alignment: .top)]
        return LazyVGrid(columns: cols, alignment: .leading, spacing: 16) {
            ForEach(tasksInSelectedCategory) { task in
                SquareDrawerTile(task: task) {
                    selectedTask = task
                }
            }
        }
    }
}
