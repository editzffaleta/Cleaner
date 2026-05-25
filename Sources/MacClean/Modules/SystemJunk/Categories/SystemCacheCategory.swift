import Foundation
import MacCleanKit

struct SystemCacheCategory: JunkCategory {
    let scanCategory = ScanCategory.systemCaches

    var targets: [ScanTarget] {
        [
            ScanTarget(path: MCConstants.systemCaches, recursive: true),
        ]
    }
}
