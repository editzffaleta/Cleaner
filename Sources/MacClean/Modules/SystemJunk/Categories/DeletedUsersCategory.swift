import Foundation
import MacCleanKit

struct DeletedUsersCategory: JunkCategory {
    let scanCategory = ScanCategory.deletedUsers

    // Scans /Users for folders not matching any active user account.
    // Requires elevated privileges to enumerate properly.
    var targets: [ScanTarget] {
        []
    }
}
