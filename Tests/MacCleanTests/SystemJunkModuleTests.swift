import XCTest
import Foundation
@testable import MacClean
import MacCleanKit

final class SystemJunkModuleTests: XCTestCase {

    func testRegistersAll20Categories() {
        XCTAssertEqual(SystemJunkModule.allCategories.count, 20)
    }

    func testAllCategoriesAreUnique() {
        let scanCategories = SystemJunkModule.allCategories.map { $0.scanCategory }
        XCTAssertEqual(Set(scanCategories).count, scanCategories.count,
                       "Every category must declare a distinct ScanCategory")
    }

    func testModuleMetadata() {
        let m = SystemJunkModule()
        XCTAssertEqual(m.id, "system_junk")
        // `name` is localized display text (PT/ZH) — the stable contract is the
        // id/category, so just assert the name is present, not a fixed string.
        XCTAssertFalse(m.name.isEmpty)
        XCTAssertEqual(m.category, .cleanup)
        XCTAssertTrue(m.includedInSmartScan)
    }
}
