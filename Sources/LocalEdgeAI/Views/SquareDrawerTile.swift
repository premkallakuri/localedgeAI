import SwiftUI

/// Port of `SquareDrawerItem` from Gallery (Android Compose).
/// 1:1 aspect ratio, 24pt corner radius, 2pt border in surfaceContainerHigh,
/// 40pt icon top-left, label + 2-line description bottom-left.
struct SquareDrawerTile: View {
    let task: GalleryTask
    let onClick: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.customColors) private var custom
    @State private var hover = false

    /// Pick one of the 4 Android task gradients for the icon based on task identity.
    private var iconGradient: LinearGradient {
        let idx: Int = {
            switch task.id {
            case .llmChat:           return 2     // blue
            case .llmAgentChat:      return 0     // red
            case .llmHermesAgent:    return 0     // red — matches Agents category
            case .llmAskImage:       return 1     // green
            case .llmAskAudio:       return 0     // red
            case .llmPromptLab:      return 3     // yellow
            case .llmMobileActions:  return 2     // blue
            case .llmTinyGarden:     return 1     // green
            case .modelManager:      return 2     // blue
            case .benchmark:         return 3     // yellow
            }
        }()
        let colors = custom.taskBgGradients[idx]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                iconBadge
                Spacer()
                if task.newBadge {
                    chip("NEW", bg: custom.newFeatureContainer, fg: custom.newFeatureText)
                } else if task.experimental {
                    chip("EXPERIMENTAL", bg: custom.warningContainer, fg: custom.warningText)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Text(task.label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.onSurface)
                Text(task.shortDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(hover ? palette.surfaceContainerLow : custom.taskCardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(palette.surfaceContainerHigh, lineWidth: 2)
        )
        .scaleEffect(hover ? 0.985 : 1.0)
        .animation(.easeOut(duration: 0.12), value: hover)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        // Use onTapGesture rather than a Button — under macOS 26 / Tahoe the
        // combination of LazyVGrid + .buttonStyle(.plain) + NavigationStack
        // misroutes synthetic clicks. onTapGesture fires reliably.
        .onTapGesture { onClick() }
        .onHover { hover = $0 }
    }

    /// Icon rendered with a Material-style gradient mask, matching SquareDrawerItem's `iconBrush`.
    private var iconBadge: some View {
        Image(systemName: task.iconName)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(iconGradient)
            .frame(width: 40, height: 40, alignment: .leading)
    }

    private func chip(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(bg))
            .foregroundStyle(fg)
    }
}
