import SwiftUI

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#elseif os(iOS) || os(tvOS) || os(visionOS)
import UIKit
public typealias PlatformImage = UIImage
public extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif

/// Cross-platform side-by-side split. Uses HSplitView (with the macOS resize
/// handle) on macOS; falls back to a plain HStack on iOS/iPadOS so the same
/// SwiftUI source compiles for both platforms.
struct AdaptiveSplit<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        #if os(macOS)
        HSplitView { content() }
        #else
        HStack(spacing: 0) { content() }
        #endif
    }
}
