import XCTest
import Foundation
@testable import MacCleanKit

final class MacCleanKitModelTests: XCTestCase {

    // MARK: - FileItem

    func testFileItemCreation() {
        let url = URL(filePath: "/tmp/test.txt")
        let item = FileItem(
            url: url,
            name: "test.txt",
            size: 1024,
            allocatedSize: 4096,
            isDirectory: false,
            contentType: .plainText,
            creationDate: Date(),
            modificationDate: Date()
        )

        XCTAssertEqual(item.name, "test.txt")
        XCTAssertEqual(item.size, 1024)
        XCTAssertEqual(item.allocatedSize, 4096)
        XCTAssertFalse(item.isDirectory)
        XCTAssertEqual(item.fileExtension, "txt")
    }

    func testFileItemAge() {
        let pastDate = Date().addingTimeInterval(-3600)
        let item = FileItem(
            url: URL(filePath: "/tmp/old.txt"),
            name: "old.txt",
            size: 100,
            allocatedSize: 100,
            isDirectory: false,
            modificationDate: pastDate
        )
        XCTAssertNotNil(item.age)
        XCTAssertGreaterThan(item.age!, 3500)
    }

    func testFileItemAgeNil() {
        let item = FileItem(
            url: URL(filePath: "/tmp/new.txt"),
            name: "new.txt",
            size: 100,
            allocatedSize: 100,
            isDirectory: false
        )
        XCTAssertNil(item.age)
    }

    // MARK: - AppInfo

    func testAppInfoCreation() {
        let app = AppInfo(
            bundleIdentifier: "com.test.app",
            name: "Test App",
            path: URL(filePath: "/Applications/Test.app"),
            version: "1.0",
            size: 50_000_000
        )

        XCTAssertEqual(app.bundleIdentifier, "com.test.app")
        XCTAssertEqual(app.name, "Test App")
        XCTAssertFalse(app.isAppleApp)
    }

    func testAppInfoUnused() {
        let oldDate = Date().addingTimeInterval(-200 * 24 * 3600) // 200 days ago
        let app = AppInfo(
            bundleIdentifier: "com.test.old",
            name: "Old App",
            path: URL(filePath: "/Applications/Old.app"),
            lastOpened: oldDate
        )
        XCTAssertTrue(app.isUnused)

        let recentApp = AppInfo(
            bundleIdentifier: "com.test.recent",
            name: "Recent App",
            path: URL(filePath: "/Applications/Recent.app"),
            lastOpened: Date()
        )
        XCTAssertFalse(recentApp.isUnused)
    }

    func testAppInfoFormattedSize() {
        let app = AppInfo(
            bundleIdentifier: "com.test.app",
            name: "Test",
            path: URL(filePath: "/Applications/Test.app"),
            size: 50_000_000
        )
        XCTAssertTrue(app.formattedSize.contains("50") || app.formattedSize.contains("47"))
    }

    // MARK: - ScanCategory

    func testScanCategoryCount() {
        XCTAssertGreaterThanOrEqual(ScanCategory.allCases.count, 20)
    }

    func testScanCategoryIDs() {
        let ids = ScanCategory.allCases.map(\.id)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "All category IDs must be unique")
    }

    // MARK: - ScanResult / ModuleScanResult

    func testModuleScanResult() {
        let items1 = [
            FileItem(url: URL(filePath: "/a"), name: "a", size: 500, allocatedSize: 500, isDirectory: false),
        ]
        let items2 = [
            FileItem(url: URL(filePath: "/b"), name: "b", size: 300, allocatedSize: 300, isDirectory: false),
            FileItem(url: URL(filePath: "/c"), name: "c", size: 200, allocatedSize: 200, isDirectory: false),
        ]
        let moduleResult = ModuleScanResult(
            moduleID: "test",
            moduleName: "Test Module",
            categories: [
                ScanResult(category: .userCaches, items: items1),
                ScanResult(category: .userLogs, items: items2),
            ],
            scanDuration: 1.5
        )

        XCTAssertEqual(moduleResult.totalSize, 1000)
        XCTAssertEqual(moduleResult.totalFileCount, 3)
    }

    // MARK: - HelperProtocol

    func testHelperProtocolExists() {
        // Verify the protocol can be referenced
        let _: MacCleanHelperProtocol.Type = MacCleanHelperProtocol.self
    }
}
