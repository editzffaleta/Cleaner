import Foundation
import MacCleanKit

protocol JunkCategory: Sendable {
    var scanCategory: ScanCategory { get }
    var targets: [ScanTarget] { get }
}
