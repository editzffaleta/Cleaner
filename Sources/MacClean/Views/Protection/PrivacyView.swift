import SwiftUI
import MacCleanKit

struct PrivacyView: View {
    @Environment(AppState.self) private var appState
    @State private var results: [ScanResult] = []
    @State private var selectedItems: Set<URL> = []
    @State private var isScanning = false
    @State private var isDone = false
    @State private var freedSize: UInt64 = 0
    @State private var timeFilter: PrivacyModule.TimeFilter = .allTime

    var body: some View {
        ModuleContainerView(
            title: "Privacy",
            subtitle: "Clean browser data, history, cookies, and system traces",
            theme: .protection,
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
            let module = PrivacyModule(timeFilter: timeFilter)
            results = await module.scan()
            for r in results { selectedItems.formUnion(r.items.map(\.url)) }
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
