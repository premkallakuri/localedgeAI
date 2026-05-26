import SwiftUI

/// Lightweight Markdown renderer tuned for chat assistant output.
///
/// Splits the source into block-level units (paragraphs, headings, bullet
/// lists, numbered lists, fenced code blocks) and renders each with proper
/// SwiftUI styling. Inline formatting (bold, italics, inline code, links)
/// is delegated to AttributedString's built-in Markdown parser — that ships
/// on macOS 12+ / iOS 15+ and handles the common cases correctly.
///
/// Code fences use a monospaced background-tinted box that mirrors Android's
/// `BufferedFadingMarkdownText` look.
struct MarkdownText: View {
    let source: String
    @Environment(\.palette) private var palette
    @Environment(\.customColors) private var custom

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                render(block: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Block parsing

    private enum Block {
        case heading(level: Int, text: String)
        case paragraph(String)
        case bullet([String])
        case numbered([String])
        case codeFence(language: String?, body: String)
        case rule
    }

    private var blocks: [Block] {
        var out: [Block] = []
        let lines = source.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body = ""
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body += lines[i] + "\n"
                    i += 1
                }
                if i < lines.count { i += 1 } // consume closing fence
                out.append(.codeFence(language: lang.isEmpty ? nil : lang, body: body))
                continue
            }

            // Heading
            if let m = trimmed.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                let level = trimmed.distance(from: trimmed.startIndex, to: m.upperBound) - 1
                let text = String(trimmed[m.upperBound...])
                out.append(.heading(level: level, text: text))
                i += 1; continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                out.append(.rule); i += 1; continue
            }

            // Bullet list (- or *)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("- ") || t.hasPrefix("* ") {
                        items.append(String(t.dropFirst(2)))
                        i += 1
                    } else { break }
                }
                out.append(.bullet(items)); continue
            }

            // Numbered list (1. 2. 3.)
            if trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                var items: [String] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    if let r = t.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                        items.append(String(t[r.upperBound...]))
                        i += 1
                    } else { break }
                }
                out.append(.numbered(items)); continue
            }

            // Blank line — end of paragraph (already separated by ForEach spacing)
            if trimmed.isEmpty { i += 1; continue }

            // Paragraph: gather contiguous non-blank, non-special lines
            var para = trimmed
            i += 1
            while i < lines.count {
                let t = lines[i].trimmingCharacters(in: .whitespaces)
                if t.isEmpty
                    || t.hasPrefix("```")
                    || t.hasPrefix("- ") || t.hasPrefix("* ")
                    || t.range(of: #"^#{1,6}\s+"#, options: .regularExpression) != nil
                    || t.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                    break
                }
                para += " " + t
                i += 1
            }
            out.append(.paragraph(para))
        }
        return out
    }

    // MARK: - Rendering

    @ViewBuilder
    private func render(block: Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inlineAttributed(text))
                .font(headingFont(level))
                .foregroundStyle(palette.onSurface)
                .padding(.top, level <= 2 ? 4 : 2)

        case .paragraph(let text):
            Text(inlineAttributed(text))
                .font(.system(size: 13))
                .foregroundStyle(palette.onSurface)
                .fixedSize(horizontal: false, vertical: true)

        case .bullet(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").foregroundStyle(palette.onSurfaceVariant)
                        Text(inlineAttributed(item))
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .numbered(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(idx + 1).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(minWidth: 18, alignment: .trailing)
                        Text(inlineAttributed(item))
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .codeFence(let language, let body):
            VStack(alignment: .leading, spacing: 4) {
                if let lang = language, !lang.isEmpty {
                    Text(lang.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                Text(body.trimmingCharacters(in: .newlines))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.onSurface)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.surfaceContainerHigh))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.outlineVariant.opacity(0.5)))
                    .textSelection(.enabled)
            }

        case .rule:
            Divider().background(palette.outlineVariant)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 22, weight: .semibold)
        case 2: return .system(size: 18, weight: .semibold)
        case 3: return .system(size: 16, weight: .semibold)
        default: return .system(size: 14, weight: .semibold)
        }
    }

    /// Use AttributedString's Markdown parser for inline formatting (bold,
    /// italic, inline code, links). Falls back to the raw string if parsing
    /// fails on the line.
    private func inlineAttributed(_ s: String) -> AttributedString {
        if let a = try? AttributedString(markdown: s,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return a
        }
        return AttributedString(s)
    }
}
