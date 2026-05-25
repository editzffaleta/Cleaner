import SwiftUI
import MacCleanKit

struct TrashBinsView: View {
    @Environment(AppState.self) private var appState
    @State private var results: [ScanResult] = []
    @State private var selectedItems: Set<URL> = []
    @State private var isScanning = false
    @State private var isDone = false
    @State private var freedSize: UInt64 = 0

    private let module = TrashBinsModule()

    var body: some View {
        ModuleContainerView(
            title: "Trash Bins",
            subtitle: "Empty all trash locations including external drives",
            theme: .cleanup,
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
            results = await module.scan()
            for r in results where r.autoSelect {
                selectedItems.formUnion(r.items.map(\.url))
            }
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
        results = []
        selectedItems = []
        isDone = false
        freedSize = 0
    }
}
