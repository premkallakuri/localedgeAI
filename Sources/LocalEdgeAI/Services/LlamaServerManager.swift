#if os(macOS)
import Foundation
import AppKit

/// Starts and supervises the bundled `llama-server` binary on macOS.
@MainActor
final class LlamaServerManager {
    static let shared = LlamaServerManager()

    private var process: Process?
    private var logHandle: FileHandle?
    private let port: Int = 8088
    private let host = "127.0.0.1"

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }

    /// Ensures llama-server is responding on localhost before the UI probes models.
    func ensureRunning() async {
        if await isHealthy() { return }

        guard let serverURL = bundledServerURL else {
            print("[LlamaServerManager] bundled llama-server not found")
            return
        }

        guard let modelPath = resolveModelPath() else {
            print("[LlamaServerManager] no bundled model found")
            return
        }

        stop()

        let proc = Process()
        proc.executableURL = serverURL
        proc.arguments = [
            "--model", modelPath,
            "--host", host,
            "--port", "\(port)",
            "--ctx-size", "4096",
            "--n-gpu-layers", "99",
        ]
        proc.currentDirectoryURL = serverURL.deletingLastPathComponent()

        if let libDir = bundledLibDirectory {
            var env = ProcessInfo.processInfo.environment
            // Resolve Homebrew-linked llama-server against bundled copies of its dylibs.
            env["DYLD_LIBRARY_PATH"] = libDir
            env["DYLD_FALLBACK_LIBRARY_PATH"] = libDir
            proc.environment = env
        }

        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("localedge-llama-server.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            proc.standardOutput = handle
            proc.standardError = handle
            logHandle = handle
        }

        do {
            try proc.run()
            process = proc
        } catch {
            print("[LlamaServerManager] failed to launch llama-server: \(error)")
            return
        }

        for _ in 0..<120 {
            if await isHealthy() { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        print("[LlamaServerManager] llama-server did not become healthy within 60s")
    }

    func stop() {
        if let proc = process, proc.isRunning {
            proc.terminate()
            proc.waitUntilExit()
        }
        process = nil
        try? logHandle?.close()
        logHandle = nil
    }

    private var bundledServerURL: URL? {
        guard let base = Bundle.main.resourceURL else { return nil }
        let url = base.appendingPathComponent("Engine/llama-server")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private var bundledLibDirectory: String? {
        guard let base = Bundle.main.resourceURL else { return nil }
        let dir = base.appendingPathComponent("Engine/lib")
        return FileManager.default.fileExists(atPath: dir.path) ? dir.path : nil
    }

    private func resolveModelPath() -> String? {
        let name = AppConfig.shared.defaultModel
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Models"),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled.path
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppConfig.shared.appName, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: appSupport.path) {
            return appSupport.path
        }
        return nil
    }

    private func isHealthy() async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/v1/models") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
#endif
