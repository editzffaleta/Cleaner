import XCTest
import Foundation
@testable import MacClean
@testable import MacCleanKit
import MacCleanTestSupport

/// End-to-end tests for the Smart Scan flow. We use fake modules for
/// most assertions so the suite doesn't scan the user's actual home dir
/// (which can take minutes and produces flaky timing).
@MainActor
final class SmartScanE2ETests: XCTestCase {

    func testCoordinatorAggregatesAllRegisteredModules() async {
        let coord = ScanCoordinator()
        coord.registerModules([
            ScanCoordinatorTests.FakeModule(
                id: "a", name: "A",
                result: [ScanResult(
                    category: .userCaches,
                    items: [FileItem(url: URL(filePath: "/tmp/a.cache"),
                                     name: "a.cache", size: 100, allocatedSize: 100,
                                     isDirectory: false)]
                )]
            ),
            ScanCoordinatorTests.FakeModule(
                id: "b", name: "B",
                result: [ScanResult(
                    category: .userLogs,
                    items: [FileItem(url: URL(filePath: "/tmp/b.log"),
                                     name: "b.log", size: 200, allocatedSize: 200,
                                     isDirectory: false)]
                )]
            ),
        ])
        coord.scanAll()

        for _ in 0..<100 {
            if case .completed = coord.state { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard case .completed(let results) = coord.state else {
            return XCTFail("Expected completed, got \(coord.state)")
        }
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(coord.filesScanned, 2)
        XCTAssertEqual(coord.totalSizeFound, 300)
    }

    func testCoordinatorStateTransitions() async {
        // idle → completed for an empty module set
        let coord = ScanCoordinator()
        guard case .idle = coord.state else {
            return XCTFail("Initial state should be idle")
        }

        coord.registerModule(ScanCoordinatorTests.FakeModule(id: "x", name: "X", result: []))
        coord.scanAll()
        for _ in 0..<50 {
            if case .completed = coord.state { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard case .completed = coord.state else {
            return XCTFail("Should be completed by now")
        }
    }
}
