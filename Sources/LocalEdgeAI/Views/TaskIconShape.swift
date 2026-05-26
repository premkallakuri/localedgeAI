import SwiftUI

/// Replicates Android's `TaskIcon` — a colored squircle/hex backdrop with a
/// white icon centered on top. Android draws an Image with one of 4 decorative
/// background shapes (`circle.xml`, `double_circle.xml`, `pantegon.xml`,
/// `four_circle.xml`) blended with the task gradient. We approximate with a
/// single rounded squircle filled by the gradient, which is what the user
/// effectively sees in the screenshots.
struct TaskIconShape: View {
    let task: GalleryTask
    var width: CGFloat = 64

    @Environment(\.customColors) private var custom

    private var gradient: LinearGradient {
        let idx: Int = {
            switch task.id {
            case .llmChat:           return 2     // blue
            case .llmAgentChat:      return 0     // red
            case .llmHermesAgent:    return 0     // red
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
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.30, style: .continuous)
                .fill(gradient)
            Image(systemName: task.iconName)
                .font(.system(size: width * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: width, height: width)
    }
}
