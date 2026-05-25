import Foundation
import MacCleanKit

struct IOSDeviceBackupsCategory: JunkCategory {
    let scanCategory = ScanCategory.iosDeviceBackups

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.mobileBackups,
                recursive: false,
                minAge: 30 * 24 * 3600 // older than 30 days
            ),
        ]
    }
}
