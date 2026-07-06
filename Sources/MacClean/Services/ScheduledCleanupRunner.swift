import Foundation
import MacCleanKit

/// Runs the automatic cleanup when it's due. Scans System Junk directly (not
/// through the shared `ScanCoordinator`, so it never disturbs whatever the user
/// is doing) and cleans only the safe, auto-selected (regenerable) categories —
/// caches, logs, and the like — always to the Trash, and records the result in
/// the cleanup history.
@MainActor
enum ScheduledCleanupRunner {
    private static var isRunning = false

    /// Fire a scheduled clean if one is due. Marks the run up-front so a slow
    /// clean can't be double-triggered by the next tick.
    static func runIfDue(engine: CleaningEngine) {
        guard ScheduledCleanup.isDue, !isRunning else { return }
        isRunning = true
        ScheduledCleanup.markRun()
        Task {
            await perform(engine: engine)
            isRunning = false
        }
    }

    static func perform(engine: CleaningEngine) async {
        let results = await SystemJunkModule().scan()
        let safe = results.filter { $0.autoSelect && !$0.items.isEmpty }
        guard !safe.isEmpty else { return }
        let selection = Set(safe.flatMap { $0.items.map(\.url) })
        _ = await CleanActions.executeUserClean(
            results: safe,
            selectedItems: selection,
            engine: engine,
            source: CleanHistorySource.scheduled
        )
    }
}
