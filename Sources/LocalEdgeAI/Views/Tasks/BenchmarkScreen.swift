import SwiftUI

struct BenchmarkResult: Identifiable {
    var id = UUID()
    let model: String
    let tps: Double
    let evalCount: Int
    let totalSec: Double
    let date: Date
}

@MainActor
final class BenchmarkViewModel: ObservableObject {
    @Published var prompt: String = "Write a 200-word factual paragraph about the lifecycle of stars, suitable for a high-school textbook."
    @Published var maxTokens: Int = 200
    @Published var selectedModel: String = ""
    @Published var results: [BenchmarkResult] = []
    @Published var running = false
    @Published var status: String = ""
    weak var appState: AppState?
    init() {
        self.selectedModel = AppConfig.shared.defaultModel
    }

    func run() {
        guard !running, let client = appState?.client else {
            status = "No inference client available"
            return
        }
        running = true
        status = "Warming up \(selectedModel)…"
        let model = selectedModel
        let prompt = self.prompt
        let max = self.maxTokens
        Task {
            do {
                let res = try await client.generateOnce(model: model, prompt: prompt, maxTokens: max)
                let secs = Double(res.totalNs ?? 0) / 1_000_000_000.0
                let tps = secs > 0 ? Double(res.evalCount ?? 0) / secs : 0
                await MainActor.run {
                    self.results.insert(BenchmarkResult(model: model, tps: tps, evalCount: res.evalCount ?? 0, totalSec: secs, date: Date()), at: 0)
                    self.status = String(format: "Done — %.1f tok/s", tps)
                    self.running = false
                }
            } catch {
                await MainActor.run {
                    self.status = "Error: \(error.localizedDescription)"
                    self.running = false
                }
            }
        }
    }
}

struct BenchmarkScreen: View {
    let task: GalleryTask
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: BenchmarkViewModel
    @Environment(\.palette) private var palette

    init(task: GalleryTask) {
        self.task = task
        _vm = StateObject(wrappedValue: BenchmarkViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            TaskHeader(task: task)
            AdaptiveSplit {
                controls.frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
                resultsList.frame(minWidth: 380)
            }
        }
        .onAppear {
            vm.appState = appState
            if vm.selectedModel.isEmpty || !appState.availableModels.contains(where: { $0.name == vm.selectedModel }) {
                vm.selectedModel = appState.defaultModel
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("BENCHMARK SETUP")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.onSurfaceVariant)

            Text("Model").font(.system(size: 11))
            Picker("", selection: $vm.selectedModel) {
                ForEach(appState.availableModels) { m in
                    Text(m.name).tag(m.name)
                }
            }
            .labelsHidden()

            Text("Prompt").font(.system(size: 11))
            TextEditor(text: $vm.prompt)
                .font(.system(size: 11))
                .frame(minHeight: 120)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surfaceContainerLowest))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.outlineVariant))

            HStack {
                Text("Max tokens").font(.system(size: 11))
                Spacer()
                Stepper(value: $vm.maxTokens, in: 50...1000, step: 50) {
                    Text("\(vm.maxTokens)").font(.system(size: 11).monospacedDigit())
                }
                .labelsHidden()
            }

            Button {
                vm.run()
            } label: {
                if vm.running {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Run benchmark", systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.running)

            if !vm.status.isEmpty {
                Text(vm.status).font(.system(size: 11)).foregroundStyle(palette.onSurfaceVariant)
            }
            Spacer()
        }
        .padding(16)
        .background(palette.surfaceContainerLow)
    }

    private var resultsList: some View {
        ScrollView {
            if vm.results.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speedometer").font(.system(size: 40)).foregroundStyle(palette.onSurfaceVariant)
                    Text("No benchmark results").font(.system(size: 13)).foregroundStyle(palette.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(vm.results) { r in
                        resultCard(r)
                    }
                }
                .padding(16)
            }
        }
        .background(palette.background)
    }

    private func resultCard(_ r: BenchmarkResult) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.model).font(.system(size: 13, weight: .semibold))
                Text(r.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10)).foregroundStyle(palette.onSurfaceVariant)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", r.tps))
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(palette.primary)
                Text("tok/s").font(.system(size: 10)).foregroundStyle(palette.onSurfaceVariant)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(r.evalCount)").font(.system(size: 13).monospacedDigit())
                Text("tokens").font(.system(size: 10)).foregroundStyle(palette.onSurfaceVariant)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2fs", r.totalSec)).font(.system(size: 13).monospacedDigit())
                Text("total").font(.system(size: 10)).foregroundStyle(palette.onSurfaceVariant)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(palette.surfaceContainerLow))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.outlineVariant))
    }
}
