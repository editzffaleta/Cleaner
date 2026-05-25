import Foundation
import MacCleanKit

struct UnusedDiskImagesCategory: JunkCategory {
    let scanCategory = ScanCategory.unusedDiskImages

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.downloads,
                recursive: false,
                fileExtensions: ["dmg", "iso", "sparseimage"],
                minAge: 7 * 24 * 3600 // older than 7 days
            ),
        ]
    }
}
