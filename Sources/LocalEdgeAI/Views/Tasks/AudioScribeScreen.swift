import SwiftUI

struct AudioScribeScreen: View {
    let task: GalleryTask
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            VStack(spacing: 18) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 56))
                    .foregroundStyle(task.tint.opacity(0.7))
                Text("Audio Scribe")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.onSurface)
                Text("Drop a .wav or .m4a file, or hit record. Transcription runs through whisper.cpp when available.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                HStack(spacing: 10) {
                    Button {} label: {
                        Label("Choose audio…", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    Button {} label: {
                        Label("Record", systemImage: "record.circle.fill")
                            .foregroundStyle(palette.error)
                    }
                    .buttonStyle(.bordered)
                }
                comingSoonBanner
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
        }
    }

    private var comingSoonBanner: some View {
        Text("Local whisper.cpp integration ships in a follow-up build. The UI surface here mirrors Gallery's iOS/Android Audio Scribe.")
            .font(.system(size: 11))
            .foregroundStyle(palette.onSurfaceVariant)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(palette.surfaceContainerLow))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.outlineVariant))
    }
}
