import XCTest
import Foundation
@testable import MacClean
@testable import MacCleanKit
import MacCleanTestSupport

/// **Wire-test** for the production Clean code path.
///
/// These tests are the regression-net for the May 2026 "scan finds junk but
/// nothing gets deleted" bug. Where `CleaningEngineTests` proves the *engine*
/// behaves correctly when given `.trash`, these tests prove the *view layer*
/// invokes the engine such that files actually move to Trash.
///
/// Methodology:
///   - Create real files under `~/Library/Caches/MacCleanTest-<uuid>/`
///     (an allowed safe-path so SafetyGuard permits operations).
///   - Build the exact `ScanResult` / `selectedItems` shape that a view
///     would assemble.
///   - Call `CleanActions.executeUserClean` — the same code path every
///     production Clean button uses.
///   - Assert the files are GONE from disk.
///
/// If anyone ever reintroduces `.dryRun` into `CleanActions`, these tests
/// fail immediately.
final class CleanActionsTests: XCTestCase {

    private var testDir: URL!

    override func setUpWithError() throws {
        // Each test gets its own subdir of user caches.
        testDir = MCConstants.userCaches
            .appending(path: "MacCleanCleanActionsTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDir)
    }

    // MARK: - Helpers

    /// Writes a real file of the given size; returns a FileItem describing it.
    private func writeReal(_ name: String, size: UInt64 = 100) throws -> (url: URL, item: FileItem) {
        let url = testDir.appending(path: name)
        try Data(count: Int(size)).write(to: url)
        let item = FileItem(
            url: url, name: name,
            size: size, allocatedSize: size,
            isDirectory: false
        )
        return (url, item)
    }

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    // MARK: - The big one: files actually leave the filesystem

    func testProductionPath_actuallyMovesSelectedFilesToTrash() async throws {
        let (urlA, itemA) = try writeReal("a.cache", size: 100)
        let (urlB, itemB) = try writeReal("b.cache", size: 200)
        let (urlC, itemC) = try writeReal("c.cache", size: 300)

        // Sanity: all three exist before
        XCTAssertTrue(exists(urlA))
        XCTAssertTrue(exists(urlB))
        XCTAssertTrue(exists(urlC))

        let results = [ScanResult(category: .userCaches, items: [itemA, itemB, itemC])]
        let selected: Set<URL> = [urlA, urlB, urlC]

        let result = await CleanActions.executeUserClean(
            results: results,
            selectedItems: selected,
            engine: CleaningEngine()
        )

        // The bug condition: dryRun would report 3 removed but files still exist.
        // Real trash: files are gone from the original path AND the report is accurate.
        XCTAssertFalse(exists(urlA), "a.cache should be gone from \(urlA.path(percentEncoded: false)) — if this fails, Clean is in dry-run mode")
        XCTAssertFalse(exists(urlB), "b.cache should be gone")
        XCTAssertFalse(exists(urlC), "c.cache should be gone")
        XCTAssertEqual(result.removedCount, 3)
        XCTAssertEqual(result.freedBytes, 600)
        XCTAssertTrue(result.errors.isEmpty)
    }

    // MARK: - Selection filtering: deselected items stay

    func testProductionPath_onlyDeletesSelectedItems() async throws {
        let (urlKeep, itemKeep) = try writeReal("keep.cache", size: 100)
        let (urlDelete, itemDelete) = try writeReal("delete.cache", size: 100)

        let results = [ScanResult(category: .userCaches, items: [itemKeep, itemDelete])]
        let selected: Set<URL> = [urlDelete] // only delete one

        let result = await CleanActions.executeUserClean(
            results: results, selectedItems: selected,
            engine: CleaningEngine()
        )

        XCTAssertTrue(exists(urlKeep), "unselected file must NOT be deleted")
        XCTAssertFalse(exists(urlDelete), "selected file must be deleted")
        XCTAssertEqual(result.removedCount, 1)
    }

    // MARK: - Empty selection is a no-op

    func testProductionPath_emptySelectionDoesNothing() async throws {
        let (url, item) = try writeReal("x.cache", size: 100)

        let results = [ScanResult(category: .userCaches, items: [item])]
        let result = await CleanActions.executeUserClean(
            results: results, selectedItems: [], // nothing selected
            engine: CleaningEngine()
        )

        XCTAssertTrue(exists(url), "file must still exist when nothing is selected")
        XCTAssertEqual(result.removedCount, 0)
        XCTAssertEqual(result.freedBytes, 0)
    }

    // MARK: - Cross-category aggregation

    func testProductionPath_aggregatesAcrossScanResultCategories() async throws {
        // A view might display multiple scan categories. The user selects items
        // from more than one. Engine must process all selected, regardless of
        // which category they came from.
        let (cacheURL, cacheItem) = try writeReal("from-caches.tmp")
        let (logURL, logItem) = try writeReal("from-logs.tmp")

        let results = [
            ScanResult(category: .userCaches, items: [cacheItem]),
            ScanResult(category: .userLogs, items: [logItem]),
        ]
        let result = await CleanActions.executeUserClean(
            results: results,
            selectedItems: [cacheURL, logURL],
            engine: CleaningEngine()
        )

        XCTAssertFalse(exists(cacheURL))
        XCTAssertFalse(exists(logURL))
        XCTAssertEqual(result.removedCount, 2)
    }

    // MARK: - Uninstaller variant (flat item list)

    func testProductionPath_uninstallerVariantDeletes() async throws {
        let (url1, item1) = try writeReal("app-leftover-1.cache", size: 50)
        let (url2, item2) = try writeReal("app-leftover-2.cache", size: 75)

        let result = await CleanActions.executeUserClean(
            items: [item1, item2],
            selectedItems: [url1, url2],
            engine: CleaningEngine()
        )

        XCTAssertFalse(exists(url1))
        XCTAssertFalse(exists(url2))
        XCTAssertEqual(result.removedCount, 2)
        XCTAssertEqual(result.freedBytes, 125)
    }

    func testProductionPath_uninstallerRespectsSelection() async throws {
        let (keepURL, keep) = try writeReal("keep-leftover.cache", size: 50)
        let (deleteURL, delete) = try writeReal("delete-leftover.cache", size: 50)

        let result = await CleanActions.executeUserClean(
            items: [keep, delete],
            selectedItems: [deleteURL],
            engine: CleaningEngine()
        )

        XCTAssertTrue(exists(keepURL))
        XCTAssertFalse(exists(deleteURL))
        XCTAssertEqual(result.removedCount, 1)
    }

    // MARK: - Safety: protected paths still blocked

    func testProductionPath_refusesProtectedSystemPath() async throws {
        // Build a ScanResult containing /System/Library — SafetyGuard should
        // reject the entire batch, no matter how the view assembled it.
        let unsafeItem = FileItem(
            url: URL(filePath: "/System/Library/CoreServices/Finder.app"),
            name: "Finder.app",
            size: 100, allocatedSize: 100,
            isDirectory: true
        )
        let results = [ScanResult(category: .userCaches, items: [unsafeItem])]

        let result = await CleanActions.executeUserClean(
            results: results,
            selectedItems: [unsafeItem.url],
            engine: CleaningEngine()
        )

        XCTAssertEqual(result.removedCount, 0, "Protected path must never be removed")
        XCTAssertFalse(result.errors.isEmpty, "Engine must report the validation failure")
    }

    // MARK: - Behavior contract: result counts match reality

    func testProductionPath_resultCountsMatchFilesystemReality() async throws {
        // The bug we caught was "reports success but did nothing." Verify the
        // engine's report matches what's actually on disk after.
        var urls: [URL] = []
        var items: [FileItem] = []
        for i in 0..<5 {
            let (u, it) = try writeReal("file-\(i).cache", size: UInt64(i + 1) * 100)
            urls.append(u)
            items.append(it)
        }
        let expectedBytes: UInt64 = items.reduce(0) { $0 + $1.size }

        let result = await CleanActions.executeUserClean(
            results: [ScanResult(category: .userCaches, items: items)],
            selectedItems: Set(urls),
            engine: CleaningEngine()
        )

        // Count matches files actually removed
        let stillExisting = urls.filter { exists($0) }
        XCTAssertEqual(stillExisting.count, 0, "All selected files should be gone")
        XCTAssertEqual(result.removedCount, urls.count)
        XCTAssertEqual(result.freedBytes, expectedBytes)
    }
}
