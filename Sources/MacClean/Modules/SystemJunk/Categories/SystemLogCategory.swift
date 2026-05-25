import Foundation
import MacCleanKit

struct SystemLogCategory: JunkCategory {
    let scanCategory = ScanCategory.systemLogs

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.systemLogs,
                recursive: true,
                fileExtensions: ["log", "txt", "crash", "diag"]
            ),
            ScanTarget(
                path: MCConstants.varLog,
                recursive: true,
                fileExtensions: ["log", "gz"]
            ),
        ]
    }
}
