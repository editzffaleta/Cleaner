import Foundation
import MacCleanKit

struct BrokenLoginItemsCategory: JunkCategory {
    let scanCategory = ScanCategory.brokenLoginItems

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userLaunchAgents,
                recursive: false,
                fileExtensions: ["plist"]
            ),
        ]
    }
}
