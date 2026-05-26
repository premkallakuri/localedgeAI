import SwiftUI
#if os(iOS) || os(visionOS)
import PhotosUI
#endif

/// Reusable streaming chat surface (transcript + composer + statusbar)
/// used by Chat, Agent, Ask Image, Tiny Garden, Mobile Actions.
struct ChatPanel: View {
    @ObservedObject var session: ChatSessionViewModel
    var showImageAttach: Bool = false
    var showThinkingToggle: Bool = false
    @Environment(\.palette) private var palette

    #if os(iOS) || os(visionOS)
    @State private var photoItem: PhotosPickerItem?
    #endif

    var body: some View {
        VStack(spacing: 0) {
            modelBar
            Divider().background(palette.outlineVariant)
            transcript
            Divider().background(palette.outlineVariant)
            composer
            statusBar
        }
        #if os(iOS) || os(visionOS)
        .photosPicker(isPresented: $session.showingImagePicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await MainActor.run { session.attach(imageData: data) }
                }
                photoItem = nil
            }
        }
        #endif
    }

    // MARK: - Model bar

    private var modelBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu").foregroundStyle(palette.primary)
            Picker("Model", selection: Binding(get: { session.model }, set: { session.model = $0 })) {
                if session.availableModels.isEmpty {
                    Text(session.model).tag(session.model)
                } else {
                    ForEach(session.availableModels) { m in
                        Text(m.name).tag(m.name)
                    }
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 280)

            if showThinkingToggle {
                Toggle("Thinking mode", isOn: $session.thinkingMode)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            Spacer()
            Button(role: .destructive) {
                session.clearChat()
            } label: {
                Label("Clear", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .help("Clear conversation")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(palette.surfaceContainerLow)
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if session.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(session.messages) { msg in
                            MessageBubble(message: msg, task: session.task)
                                .id(msg.id)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.background)
            .onChange(of: session.messages.last?.content) { _ in
                if let last = session.messages.last {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.task.label)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.onSurface)
            Text(session.task.description)
                .font(.system(size: 13))
                .foregroundStyle(palette.onSurfaceVariant)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !session.attachedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(session.attachedImages.enumerated()), id: \.offset) { i, data in
                            if let nsi = PlatformImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(platformImage: nsi)
                                        .resizable().scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    Button {
                                        session.attachedImages.remove(at: i)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(2)
                                }
                            }
                        }
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                if showImageAttach {
                    Button {
                        session.openImagePicker()
                    } label: {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.borderless)
                    .help("Attach image")
                    .frame(width: 36, height: 36)
                }
                TextEditor(text: $session.input)
                    .font(.system(size: 13))
                    .frame(minHeight: 48, maxHeight: 120)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.surfaceContainerLowest))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.outlineVariant))
                Button {
                    session.send()
                } label: {
                    if session.isStreaming {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(session.isStreaming || (session.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && session.attachedImages.isEmpty))
                .frame(width: 44, height: 44)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(palette.surfaceContainerLow)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(session.connectionOK ? Color(hex: 0x34A853) : palette.error).frame(width: 8, height: 8)
            Text(session.statusLine.isEmpty ? "Idle" : session.statusLine)
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .lineLimit(1)
            Spacer()
            if let tps = session.lastTokensPerSec {
                Text(String(format: "%.1f tok/s", tps))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(palette.onSurfaceVariant)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(palette.surfaceContainer)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let task: GalleryTask
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.18))
                Image(systemName: avatarIcon).foregroundStyle(tint)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(authorLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.onSurfaceVariant)

                if let imgs = message.images, !imgs.isEmpty {
                    HStack {
                        ForEach(Array(imgs.enumerated()), id: \.offset) { _, b64 in
                            if let data = Data(base64Encoded: b64), let img = PlatformImage(data: data) {
                                Image(platformImage: img).resizable().scaledToFit().frame(maxWidth: 220, maxHeight: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                Group {
                    if message.role == .assistant {
                        // Assistant text rendered as Markdown (matches Android
                        // BufferedFadingMarkdownText). Streamed empty content
                        // still needs a placeholder so the bubble shows.
                        let visible = MessageBubble.stripThinking(message.content)
                        if visible.isEmpty {
                            Text(" ")
                        } else {
                            MarkdownText(source: visible)
                                .textSelection(.enabled)
                        }
                    } else {
                        Text(message.content.isEmpty ? " " : message.content)
                            .textSelection(.enabled)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onSurface)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.08)))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var authorLabel: String {
        switch message.role {
        case .user: return "You"
        case .assistant: return "LocalEdge · \(task.label)"
        case .system: return "System"
        }
    }

    /// Strip any `<thinking>…</thinking>` block from the assistant text so
    /// the user only sees the final answer. Handles:
    ///   • multi-line content via DOTALL-style matching
    ///   • a partially-streamed open tag (no closing yet) — hide everything
    ///     after `<thinking>` until the matching close arrives
    ///   • surrounding whitespace + leading newline that follows the block
    static func stripThinking(_ text: String) -> String {
        var s = text
        // Closed blocks: remove fully.
        if let re = try? NSRegularExpression(
            pattern: #"<thinking>[\s\S]*?</thinking>"#, options: [.caseInsensitive]) {
            let range = NSRange(s.startIndex..., in: s)
            s = re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "")
        }
        // Open-only block (stream still in progress): drop the rest.
        if let openRange = s.range(of: "<thinking>", options: .caseInsensitive) {
            s = String(s[..<openRange.lowerBound])
        }
        // Tidy leading whitespace / newlines.
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var avatarIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return task.iconName
        case .system: return "gearshape.fill"
        }
    }
    private var tint: Color {
        switch message.role {
        case .user: return Color(hex: 0x4285F4)
        case .assistant: return task.tint
        case .system: return Color.gray
        }
    }
}
