import Foundation
import MacCleanKit

struct OldUpdatesCategory: JunkCategory {
    let scanCategory = ScanCategory.oldUpdates

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userAppSupport,
                recursive: true,
                maxDepth: 3,
                fileExtensions: ["pkg", "mpkg"],
                minAge: 7 * 24 * 3600 // older than 7 days
            ),
        ]
    }
}
