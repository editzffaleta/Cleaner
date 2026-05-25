import Foundation
import MacCleanKit

struct BrokenDownloadsCategory: JunkCategory {
    let scanCategory = ScanCategory.brokenDownloads

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.downloads,
                recursive: false,
                fileExtensions: ["download", "crdownload", "part", "partial"]
            ),
        ]
    }
}
