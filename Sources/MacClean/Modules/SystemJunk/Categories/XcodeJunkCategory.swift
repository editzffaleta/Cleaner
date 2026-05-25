import Foundation
import MacCleanKit

struct XcodeJunkCategory: JunkCategory {
    let scanCategory = ScanCategory.xcodeJunk

    var targets: [ScanTarget] {
        [
            ScanTarget(path: MCConstants.xcodeDerivedData, recursive: false),
            ScanTarget(path: MCConstants.xcodeArchives, recursive: false),
            ScanTarget(path: MCConstants.xcodeDeviceSupport, recursive: false),
            ScanTarget(path: MCConstants.coreSimulator, recursive: false),
            ScanTarget(path: MCConstants.xcodePreviews, recursive: false),
        ]
    }
}
