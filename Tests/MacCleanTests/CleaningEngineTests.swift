import XCTest
import Foundation
@testable import MacClean
@testable import MacCleanKit
import MacCleanTestSupport

/// Integration tests for `CleaningEngine`. These use real tmp directories
/// because the engine's job is to interact with the filesystem; mocking
/// `FileManager` would only test stub behavior, not the actual outcomes.
final class CleaningEngineTests: XCTestCase {

    /// The engine refuses anything outside the safe paths (`~/Library/Caches` etc.).
    /// To exercise it we need a fake item URL that's under userCaches but actually
    /// points at our tmp file via a symlink trick — too fragile. Instead, we test
    /// the engine by giving it inputs we know `SafetyGuard` allows.
    ///
    /// Strategy: write tmp files under `~/Library/Caches/MacCleanTest-<uuid>/`
    /// for the duration of the test, then clean them up.

    private static let testCachesRoot = MCConstants.userCaches
        .appending(path: "MacCleanTest-\(UUID().uuidString)")

    private static func makeTestDir() throws -> URL {
        let dir = MCConstants.userCaches
            .appending(path: "MacCleanTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func cleanupTestDir(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func makeFileItem(at url: URL, size: UInt64 = 0) -> FileItem {
        FileItem(
            url: url,
            name: url.lastPathComponent,
            size: size,
            allocatedSize: size,
            isDirectory: false
        )
    }

    // MARK: - Dry-run mode

    func testDryRunNeverDeletes() async throws {
        let dir = try Self.makeTestDir()
        defer { Self.cleanupTestDir(dir) }

        let file = dir.appending(path: "dryrun.cache")
        try TestFixtures.writeFile(at: file, size: 1234)

        let engine = CleaningEngine()
        let result = await engine.clean(items: [makeFileItem(at: file, size: 1234)], mode: .dryRun)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.freedBytes, 1234)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)),
                      "File must still exist after dry-run")
    }

    func testDryRunReportsCountsCorrectly() async throws {
        let dir = try Self.makeTestDir()
        defer { Self.cleanupTestDir(dir) }

        var items: [FileItem] = []
        for i in 0..<10 {
            let url = dir.appending(path: "f\(i).cache")
            try TestFixtures.writeFile(at: url, size: 100)
            items.append(makeFileItem(at: url, size: 100))
        }

        let result = await CleaningEngine().clean(items: items, mode: .dryRun)
        XCTAssertEqual(result.removedCount, 10)
        XCTAssertEqual(result.freedBytes, 1000)
        for item in items {
            XCTAssertTrue(FileManager.default.fileExists(atPath: item.url.path(percentEncoded: false)))
        }
    }

    // MARK: - Trash mode

    func testTrashModeMovesToTrash() async throws {
        let dir = try Self.makeTestDir()
        defer { Self.cleanupTestDir(dir) }

        let file = dir.appending(path: "trash-me.cache")
        try TestFixtures.writeFile(at: file, size: 500)

        let engine = CleaningEngine()
        let result = await engine.clean(items: [makeFileItem(at: file, size: 500)], mode: .trash)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.freedBytes, 500)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)),
                       "File should no longer be at the original path")
    }

    // MARK: - Permanent mode

    func testPermanentModeRemoves() async throws {
        let dir = try Self.makeTestDir()
        defer { Self.cleanupTestDir(dir) }

        let file = dir.appending(path: "permanent.cache")
        try TestFixtures.writeFile(at: file, size: 200)

        let engine = CleaningEngine()
        let result = await engine.clean(items: [makeFileItem(at: file, size: 200)], mode: .permanent)

        XCTAssertEqual(result.removedCount, 1)
        XCTAssertEqual(result.freedBytes, 200)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    // MARK: - Error handling

    func testMissingFileGracefullySkipped() async throws {
        let dir = try Self.makeTestDir()
        defer { Self.cleanupTestDir(dir) }

        let missingFile = dir.appending(path: "never-existed.cache")
        let result = await CleaningEngine().clean(
            items: [makeFileItem(at: missingFile, size: 0)],
            mode: .trash
        )

        // Engine reports an error for the missing file but doesn't crash.
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.removedCount, 0)
    }

    func testSafetyValidationBlocksWholeBatch() async {
        let unsafeItem = FileItem(
            url: URL(filePath: "/System/Library/CoreServices/Finder.app"),
            name: "Finder.app",
            size: 100,
            allocatedSize: 100,
            isDirectory: true
        )
        let result = await CleaningEngine().clean(items: [unsafeItem], mode: .dryRun)
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertFalse(result.errors.isEmpty)
    }

    func testTenThousandOnePathsAllRejected() async {
        let items = (0..<10_001).map {
            FileItem(
                url: MCConstants.userCaches.appending(path: "f\($0)"),
                name: "f\($0)",
                size: 0,
                allocatedSize: 0,
                isDirectory: false
            )
        }
        let result = await CleaningEngine().clean(items: items, mode: .dryRun)
        XCTAssertEqual(result.removedCount, 0,
                       "Batch over file cap must be entirely rejected, not partially processed")
        XCTAssertEqual(result.skippedCount, 10_001)
    }

    // MARK: - Empty input

    func testEmptyInputProducesNoErrors() async {
        let result = await CleaningEngine().clean(items: [], mode: .dryRun)
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.freedBytes, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.skippedCount, 0)
    }

    // MARK: - Operation log

    func testOperationLogWritten() async throws {
        let dir = try Self.makeTestDir()
        defer { Self.cleanupTestDir(dir) }

        let file = dir.appending(path: "logged-cleanup.cache")
        try TestFixtures.writeFile(at: file, size: 42)

        _ = await CleaningEngine().clean(items: [makeFileItem(at: file, size: 42)], mode: .dryRun)

        let logFile = MCConstants.operationLogFile
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFile.path(percentEncoded: false)),
                      "Operation log should exist after a clean operation")

        let contents = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
        XCTAssertTrue(contents.contains("[DRY-RUN]"),
                      "Dry-run operations should be marked [DRY-RUN] in the log")
    }
}
