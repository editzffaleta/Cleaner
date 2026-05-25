import SwiftUI
import MacCleanKit

@MainActor @Observable
final class SystemJunkViewModel {
    enum State {
        case idle
        case scanning(progress: Double)
        case results
        case cleaning
        case done(freed: UInt64)
    }

    var state: State = .idle
    var results: [ScanResult] = []
    var selectedItems: Set<URL> = []
    var filesFound: Int = 0

    private let module = SystemJunkModule()

    var totalSelectedSize: UInt64 {
        let allItems = results.flatMap(\.items)
        return allItems
            .filter { selectedItems.contains($0.url) }
            .reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        selectedItems.count
    }

    var totalFileCount: Int {
        results.reduce(0) { $0 + $1.fileCount }
    }

    func startScan() {
        state = .scanning(progress: 0)
        filesFound = 0
        results = []
        selectedItems = []

        Task {
            state = .scanning(progress: 0.3)

            let scanResults = await module.scan()

            results = scanResults
            filesFound = scanResults.reduce(0) { $0 + $1.fileCount }

            for result in scanResults where result.autoSelect {
                for item in result.items {
                    selectedItems.insert(item.url)
                }
            }

            state = .scanning(progress: 1.0)
            try? await Task.sleep(for: .milliseconds(300))
            state = .results
        }
    }

    func startCleaning(engine: CleaningEngine) {
        state = .cleaning

        Task {
            let allItems = results.flatMap(\.items)
            let itemsToClean = allItems.filter { selectedItems.contains($0.url) }

            let result = await engine.clean(items: itemsToClean, mode: .dryRun)

            state = .done(freed: result.freedBytes)
        }
    }

    func reset() {
        state = .idle
        results = []
        selectedItems = []
        filesFound = 0
    }
}
