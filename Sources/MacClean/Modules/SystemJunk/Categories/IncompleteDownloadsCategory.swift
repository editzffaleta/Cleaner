import Foundation
import MacCleanKit

struct IncompleteDownloadsCategory: JunkCategory {
    let scanCategory = ScanCategory.incompleteDownloads

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.downloads,
                recursive: false,
                fileExtensions: ["download", "crdownload", "part", "partial", "tmp"]
            ),
            ScanTarget(
                path: FileManager.default.temporaryDirectory,
                recursive: true,
                maxDepth: 2,
                minAge: 24 * 3600 // older than 1 day
            ),
        ]
    }
}
