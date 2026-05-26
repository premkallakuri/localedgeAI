import SwiftUI

#if os(macOS)
import AppKit
#endif

@main
struct LocalEdgeAIApp: App {
    init() {
        #if os(macOS)
        // Force NSApplication to instantiate (NSApp is nil this early on Tahoe
        // SwiftPM apps) then mark us a regular foreground app and activate.
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            app.activate(ignoringOtherApps: true)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup(AppConfig.shared.appName) {
            RootView()
                #if os(macOS)
                .frame(minWidth: 980, minHeight: 680)
                #endif
        }
        #if os(macOS)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppConfig.shared.appName)") {
                    let alert = NSAlert()
                    alert.messageText = AppConfig.shared.appName
                    alert.informativeText = """
                    \(AppConfig.shared.tagline)
                    Version \(AppConfig.shared.version)

                    Created by Prem Saran Kallakuri.
                    Runs Gemma, Qwen, Llama and other models locally via
                    llama.cpp on macOS and LiteRT-LM on iOS — fully offline.
                    """
                    alert.runModal()
                }
            }
        }
        #endif
    }
}
