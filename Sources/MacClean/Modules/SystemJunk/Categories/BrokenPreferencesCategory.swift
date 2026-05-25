import Foundation
import MacCleanKit

struct BrokenPreferencesCategory: JunkCategory {
    let scanCategory = ScanCategory.brokenPreferences

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userPreferences,
                recursive: false,
                fileExtensions: ["plist"]
            ),
        ]
    }
}
