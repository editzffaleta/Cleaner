import SwiftUI
import MacCleanKit

@Observable
public final class AppState {
    var selectedSidebarItem: SidebarItem? = .smartScan
    var scanCoordinator = ScanCoordinator()
    let cleaningEngine = CleaningEngine()

    var hasFullDiskAccess: Bool = false

    init() {
        registerModules()
        checkPermissions()
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

    private func checkPermissions() {
        let testPath = MCConstants.home
            .appending(path: "Library/Mail")
            .path(percentEncoded: false)
        hasFullDiskAccess = FileManager.default.isReadableFile(atPath: testPath)
    }
}
