import SwiftUI
import MacCleanKit

struct DuplicatesView: View {
    @Environment(AppState.self) private var appState
    @State private var results: [ScanResult] = []
    @State private var selectedItems: Set<URL> = []
    @State private var isScanning = false
    @State private var isDone = false
    @State private var freedSize: UInt64 = 0

    var body: some View {
        ModuleContainerView(
            title: "Duplicates",
            subtitle: "Find duplicate files using progressive hash detection",
            theme: .files,
            results: results,
            selectedItems: $selectedItems,
            isScanning: isScanning,
            isDone: isDone,
            freedSize: freedSize,
            onScan: scan,
            onClean: clean,
            onReset: reset
        )
    }

    private func scan() {
        isScanning = true
        Task {
            let module = DuplicatesModule()
            results = await module.scan()
            isScanning = false
        }
    }

    private func clean() {
        let items = results.flatMap(\.items).filter { selectedItems.contains($0.url) }
        Task {
            let result = await appState.cleaningEngine.clean(items: items, mode: .dryRun)
            freedSize = result.freedBytes
            isDone = true
        }
    }

    private func reset() {
        results = []; selectedItems = []; isDone = false; freedSize = 0
    }
}
