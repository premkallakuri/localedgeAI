import SwiftUI

/// Material 3 palette ported from Google AI Edge Gallery (Color.kt),
/// preserving the exact same light/dark tones for the rebrand.
struct GalleryPalette {
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let secondary: Color
    let secondaryContainer: Color
    let tertiary: Color
    let tertiaryContainer: Color
    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let onSurfaceVariant: Color
    let surfaceContainerLowest: Color
    let surfaceContainerLow: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let outline: Color
    let outlineVariant: Color
    let inversePrimary: Color
    let error: Color

    static let light = GalleryPalette(
        primary: Color(hex: 0x0B57D0),
        onPrimary: Color(hex: 0xFFFFFF),
        primaryContainer: Color(hex: 0xD3E3FD),
        onPrimaryContainer: Color(hex: 0x0842A0),
        secondary: Color(hex: 0x00639B),
        secondaryContainer: Color(hex: 0xC2E7FF),
        tertiary: Color(hex: 0x146C2E),
        tertiaryContainer: Color(hex: 0xC4EED0),
        background: Color(hex: 0xFFFFFF),
        onBackground: Color(hex: 0x1F1F1F),
        surface: Color(hex: 0xFFFFFF),
        onSurface: Color(hex: 0x1F1F1F),
        onSurfaceVariant: Color(hex: 0x444746),
        surfaceContainerLowest: Color(hex: 0xFFFFFF),
        surfaceContainerLow: Color(hex: 0xF8FAFD),
        surfaceContainer: Color(hex: 0xF0F4F9),
        surfaceContainerHigh: Color(hex: 0xE9EEF6),
        surfaceContainerHighest: Color(hex: 0xDDE3EA),
        outline: Color(hex: 0x747775),
        outlineVariant: Color(hex: 0xC4C7C5),
        inversePrimary: Color(hex: 0xA8C7FA),
        error: Color(hex: 0xB3261E)
    )

    static let dark = GalleryPalette(
        primary: Color(hex: 0xA8C7FA),
        onPrimary: Color(hex: 0x062E6F),
        primaryContainer: Color(hex: 0x0842A0),
        onPrimaryContainer: Color(hex: 0xD3E3FD),
        secondary: Color(hex: 0x7FCFFF),
        secondaryContainer: Color(hex: 0x004A77),
        tertiary: Color(hex: 0x6DD58C),
        tertiaryContainer: Color(hex: 0x0F5223),
        background: Color(hex: 0x131314),
        onBackground: Color(hex: 0xE3E3E3),
        surface: Color(hex: 0x131314),
        onSurface: Color(hex: 0xE3E3E3),
        onSurfaceVariant: Color(hex: 0xC4C7C5),
        surfaceContainerLowest: Color(hex: 0x0E0E0E),
        surfaceContainerLow: Color(hex: 0x1B1B1B),
        surfaceContainer: Color(hex: 0x1E1F20),   // exact from Color.kt
        surfaceContainerHigh: Color(hex: 0x282A2C),
        surfaceContainerHighest: Color(hex: 0x333537),
        outline: Color(hex: 0x8E918F),
        outlineVariant: Color(hex: 0x444746),
        inversePrimary: Color(hex: 0x0B57D0),
        error: Color(hex: 0xF2B8B5)
    )
}

/// Custom Android palette (see Theme.kt CustomColors block).
struct GalleryCustomColors {
    let appTitleGradient: [Color]            // Hero title gradient ("LocalEdge")
    let tabHeaderBg: Color                   // Active category pill bg
    let taskCardBg: Color                    // Square tile fill
    let taskBgGradients: [[Color]]           // 4 paired gradients used for icon tints
    let taskIconColors: [Color]              // Solid versions of the same 4 colors
    let userBubbleBg: Color
    let agentBubbleBg: Color
    let linkColor: Color
    let successColor: Color
    let newFeatureContainer: Color
    let newFeatureText: Color
    let warningContainer: Color
    let warningText: Color

    static let light = GalleryCustomColors(
        appTitleGradient: [Color(hex: 0x85B1F8), Color(hex: 0x3174F1)],
        tabHeaderBg: Color(hex: 0x3174F1),
        taskCardBg: Color(hex: 0xFFFFFF),
        taskBgGradients: [
            [Color(hex: 0xE25F57), Color(hex: 0xDB372D)],   // red
            [Color(hex: 0x41A15F), Color(hex: 0x128937)],   // green
            [Color(hex: 0x669DF6), Color(hex: 0x3174F1)],   // blue
            [Color(hex: 0xFDD45D), Color(hex: 0xCAA12A)],   // yellow
        ],
        taskIconColors: [Color(hex: 0xDB372D), Color(hex: 0x128937), Color(hex: 0x3174F1), Color(hex: 0xCAA12A)],
        userBubbleBg: Color(hex: 0xE9EEF6),
        agentBubbleBg: Color(hex: 0xF0F4F9),
        linkColor: Color(hex: 0x3174F1),
        successColor: Color(hex: 0x128937),
        newFeatureContainer: Color(hex: 0xD3E3FD),
        newFeatureText: Color(hex: 0x0842A0),
        warningContainer: Color(hex: 0xFEF0C7),
        warningText: Color(hex: 0x6E4D00)
    )

    static let dark = GalleryCustomColors(
        appTitleGradient: [Color(hex: 0x85B1F8), Color(hex: 0xA8C7FA)],
        tabHeaderBg: Color(hex: 0x3174F1),
        taskCardBg: Color(hex: 0x1E1F20),
        taskBgGradients: [
            [Color(hex: 0xE25F57), Color(hex: 0xDB372D)],   // red
            [Color(hex: 0x41A15F), Color(hex: 0x128937)],   // green
            [Color(hex: 0x669DF6), Color(hex: 0x3174F1)],   // blue
            [Color(hex: 0xFDD45D), Color(hex: 0xCAA12A)],   // yellow
        ],
        taskIconColors: [Color(hex: 0xE25F57), Color(hex: 0x41A15F), Color(hex: 0x669DF6), Color(hex: 0xFDD45D)],
        userBubbleBg: Color(hex: 0x282A2C),
        agentBubbleBg: Color(hex: 0x1E1F20),
        linkColor: Color(hex: 0x85B1F8),
        successColor: Color(hex: 0x41A15F),
        newFeatureContainer: Color(hex: 0x0842A0),
        newFeatureText: Color(hex: 0xD3E3FD),
        warningContainer: Color(hex: 0x4A3A00),
        warningText: Color(hex: 0xFEF0C7)
    )
}

private struct CustomColorsKey: EnvironmentKey {
    static let defaultValue: GalleryCustomColors = .dark
}
extension EnvironmentValues {
    var customColors: GalleryCustomColors {
        get { self[CustomColorsKey.self] }
        set { self[CustomColorsKey.self] = newValue }
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: GalleryPalette = .dark
}

extension EnvironmentValues {
    var palette: GalleryPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

/// Brand gradient used on the title's second half ("Gallery" replacement = "Edge").
struct BrandGradient {
    static let icon = LinearGradient(
        colors: [Color(hex: 0x4285F4), Color(hex: 0xEA4335), Color(hex: 0xFBBC05), Color(hex: 0x34A853)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let titleAccent = LinearGradient(
        colors: [Color(hex: 0x4285F4), Color(hex: 0x9C27B0)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
