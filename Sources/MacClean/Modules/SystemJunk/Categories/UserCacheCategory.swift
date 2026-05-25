import Foundation
import MacCleanKit

struct UserCacheCategory: JunkCategory {
    let scanCategory = ScanCategory.userCaches

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userCaches,
                recursive: true,
                excludePatterns: ["com.spotify.client", "org.gradle"]
            ),
        ]
    }
}
