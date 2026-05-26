import SwiftUI

struct ModelManagerScreen: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(appState.availableModels) { m in
                        modelRow(m)
                    }
                }
                .padding(20)
            }
            .background(palette.background)
        }
        .task { await appState.refreshModels() }
    }

    private func modelRow(_ m: OllamaModel) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(palette.primaryContainer.opacity(0.35))
                Image(systemName: "shippingbox.fill").foregroundStyle(palette.primary)
            }.frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(m.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.onSurface)
                    if appState.visionCapableModels.contains(m.name) {
                        chip("VISION", color: Color(hex: 0x34A853))
                    }
                    if m.name == appState.defaultModel {
                        chip("DEFAULT", color: palette.primary)
                    }
                }
                Text("Size: \(m.sizeGB)").font(.system(size: 11)).foregroundStyle(palette.onSurfaceVariant)
            }
            Spacer()
            Button {
                appState.defaultModel = m.name
            } label: {
                Text("Set default")
            }
            .buttonStyle(.bordered)
            .disabled(m.name == appState.defaultModel)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.surfaceContainerLow))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.outlineVariant))
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}
