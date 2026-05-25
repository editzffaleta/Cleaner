import Foundation
import MacCleanKit

struct UserLogCategory: JunkCategory {
    let scanCategory = ScanCategory.userLogs

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userLogs,
                recursive: true,
                fileExtensions: ["log", "txt", "crash", "diag", "ips"]
            ),
        ]
    }
}
