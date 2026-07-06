import SwiftUI
import MacCleanKit

@Observable
public final class AppState {
    var selectedSidebarItem: SidebarItem? = .home
    var scanCoordinator = ScanCoordinator()
    let cleaningEngine = CleaningEngine()
    let scanResultsStore = ScanResultsStore()

    init() {
        registerModules()
        // 30-day log retention. Runs once at app launch. Best-effort —
        // a failure here doesn't surface to the user; the unpruned log
        // is still queryable and we'll retry on the next launch.
        // Async so a slow filesystem doesn't delay window appearance.
        Task.detached(priority: .background) {
            CleanLogManager.pruneOldEntries()
        }
        // Discover installed languages off the main thread so Settings shows
        // the user's actual languages; refreshed on every launch so newly
        // added languages appear.
        Task.detached(priority: .background) {
            let found = LanguageScanner().discoverLproj(in: LanguageScanner.defaultRoots)
            await MainActor.run { LanguagePreferences.discoveredLproj = found }
        }
        // Automatic scheduled cleanup: check when the app launches and then
        // hourly while it stays open. Opt-in (off by default), independent of
        // the UI, and only ever touches safe regenerable junk (→ Trash).
        let engine = cleaningEngine
        Task { @MainActor in
            while !Task.isCancelled {
                ScheduledCleanupRunner.runIfDue(engine: engine)
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    private func registerModules() {
        scanCoordinator.registerModules([
            SystemJunkModule(),
            MailAttachmentsModule(),
            TrashBinsModule(),
            MalwareModule(),
            PrivacyModule(),
            OptimizationModule(),
            MaintenanceModule(),
            UninstallerModule(),
            UpdaterModule(),
            SpaceLensModule(),
            LargeOldFilesModule(),
            DuplicatesModule(),
            ShredderModule(),
        ])
    }

}
