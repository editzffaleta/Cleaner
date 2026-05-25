import Foundation
import MacCleanKit

struct DocumentVersionsCategory: JunkCategory {
    let scanCategory = ScanCategory.documentVersions

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.documentVersions,
                recursive: true,
                minAge: 14400 // older than 4 hours
            ),
        ]
    }
}
