import XCTest
import Foundation
import GRDB
@testable import MacClean
@testable import MacCleanKit
import MacCleanTestSupport

/// Integration tests for the GRDB-backed scan cache.
final class DatabaseTests: XCTestCase {

    /// Build an isolated database for each test.
    private func makeDB() throws -> AppDatabase {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "macclean-db-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appending(path: "test.sqlite").path(percentEncoded: false)
        let pool = try DatabasePool(path: path)
        let db = AppDatabase(dbPool: pool)
        try db.migrate()
        return db
    }

    func testCreateScanAndCompleteRoundtrip() throws {
        let db = try makeDB()
        let id = try db.createScan(rootPath: "/tmp/test", moduleID: "system_junk")
        XCTAssertGreaterThan(id, 0)

        try db.completeScan(id: id, totalSize: 1234, fileCount: 5, fsEventID: 100)

        let last = try db.lastScan(moduleID: "system_junk")
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.id, id)
        XCTAssertEqual(last?.fsEventID, 100)
    }

    func testNoLastScanForUnknownModule() throws {
        let db = try makeDB()
        XCTAssertNil(try db.lastScan(moduleID: "never_registered"))
    }

    func testCacheAndRetrieveFiles() throws {
        let db = try makeDB()
        let scanID = try db.createScan(rootPath: "/tmp/test", moduleID: "system_junk")

        let records = [
            CachedFileRecord(
                path: "/tmp/a.cache", name: "a.cache", parentPath: "/tmp",
                size: 100, allocatedSize: 100,
                isDirectory: false, category: "user_caches",
                inode: 1, deviceID: 1
            ),
            CachedFileRecord(
                path: "/tmp/b.log", name: "b.log", parentPath: "/tmp",
                size: 200, allocatedSize: 200,
                isDirectory: false, category: "user_logs",
                inode: 2, deviceID: 1
            ),
        ]
        try db.cacheFiles(records, scanID: scanID)

        let all = try db.getCachedFiles(scanID: scanID)
        XCTAssertEqual(all.count, 2)

        let userCaches = try db.getCachedFilesByCategory(scanID: scanID, category: "user_caches")
        XCTAssertEqual(userCaches.count, 1)
        XCTAssertEqual(userCaches.first?.path, "/tmp/a.cache")
    }

    func testInvalidatePaths() throws {
        let db = try makeDB()
        let scanID = try db.createScan(rootPath: "/tmp/test", moduleID: "system_junk")
        try db.cacheFiles([
            CachedFileRecord(path: "/tmp/a/x", name: "x", parentPath: "/tmp/a",
                             size: 1, allocatedSize: 1, isDirectory: false),
            CachedFileRecord(path: "/tmp/a/y", name: "y", parentPath: "/tmp/a",
                             size: 1, allocatedSize: 1, isDirectory: false),
            CachedFileRecord(path: "/tmp/b/x", name: "x", parentPath: "/tmp/b",
                             size: 1, allocatedSize: 1, isDirectory: false),
        ], scanID: scanID)

        try db.invalidatePaths(["/tmp/a"], scanID: scanID)
        let remaining = try db.getCachedFiles(scanID: scanID)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.path, "/tmp/b/x")
    }

    func testCacheAppUpsertsByBundleID() throws {
        let db = try makeDB()
        let app = AppInfo(
            bundleIdentifier: "com.test.app",
            name: "Test", path: URL(filePath: "/Applications/Test.app"),
            version: "1.0", size: 1024
        )
        try db.cacheApp(app)

        // Same bundle ID, different version - should replace, not duplicate.
        let updatedApp = AppInfo(
            bundleIdentifier: "com.test.app",
            name: "Test", path: URL(filePath: "/Applications/Test.app"),
            version: "2.0", size: 2048
        )
        try db.cacheApp(updatedApp)
        // Test passes if no crash + no UNIQUE constraint violation
    }

    func testClearOldScansKeepsRecent() throws {
        let db = try makeDB()
        for i in 0..<10 {
            let id = try db.createScan(rootPath: "/tmp/s\(i)", moduleID: "test")
            try db.completeScan(id: id, totalSize: 0, fileCount: 0, fsEventID: 0)
        }
        try db.clearOldScans(keepLast: 3)
        // We don't expose a count, but lastScan should still return the most recent.
        XCTAssertNotNil(try db.lastScan(moduleID: "test"))
    }

    func testCachedFileRecord_toFileItem() {
        let record = CachedFileRecord(
            path: "/tmp/x.txt", name: "x.txt", parentPath: "/tmp",
            size: 100, allocatedSize: 100,
            modificationDate: Date(),
            isDirectory: false, inode: 42, deviceID: 7
        )
        let item = record.toFileItem()
        XCTAssertEqual(item.url, URL(filePath: "/tmp/x.txt"))
        XCTAssertEqual(item.size, 100)
        XCTAssertEqual(item.inode, 42)
    }
}

