import XCTest
import Foundation
@testable import MacClean
@testable import MacCleanKit

final class SafetyGuardTests: XCTestCase {
    let guard_ = SafetyGuard()

    // MARK: - Protected Path Tests

    func testSystemPathBlocked() {
        XCTAssertThrowsError(try guard_.validatePath(URL(filePath: "/System/Library/something")))
    }

    func testUsrPathBlocked() {
        XCTAssertThrowsError(try guard_.validatePath(URL(filePath: "/usr/bin/ls")))
    }

    func testBinPathBlocked() {
        XCTAssertThrowsError(try guard_.validatePath(URL(filePath: "/bin/sh")))
    }

    func testSbinPathBlocked() {
        XCTAssertThrowsError(try guard_.validatePath(URL(filePath: "/sbin/mount")))
    }

    func testUserCachePathAllowed() throws {
        let path = MCConstants.userCaches.appending(path: "com.test.app")
        try guard_.validatePath(path)
    }

    func testUserLogPathAllowed() throws {
        let path = MCConstants.userLogs.appending(path: "TestApp.log")
        try guard_.validatePath(path)
    }

    func testDownloadsPathAllowed() throws {
        let path = MCConstants.downloads.appending(path: "test.dmg")
        try guard_.validatePath(path)
    }

    // MARK: - File Count Limit Tests

    func testFileCountWithinLimit() throws {
        let urls = (0..<100).map { URL(filePath: "/tmp/file\($0)") }
        try guard_.validateDeletion(paths: urls)
    }

    func testFileCountExceedsLimit() {
        let urls = (0..<10_001).map { URL(filePath: "/tmp/file\($0)") }
        XCTAssertThrowsError(try guard_.validateDeletion(paths: urls))
    }

    func testFileCountExactLimit() throws {
        let urls = (0..<10_000).map { URL(filePath: "/tmp/file\($0)") }
        try guard_.validateDeletion(paths: urls)
    }

    // MARK: - Protected App Tests

    func testAppleAppsProtected() {
        XCTAssertTrue(guard_.isProtectedApp("com.apple.finder"))
        XCTAssertTrue(guard_.isProtectedApp("com.apple.Safari"))
        XCTAssertTrue(guard_.isProtectedApp("com.apple.mail"))
        XCTAssertTrue(guard_.isProtectedApp("com.apple.Terminal"))
    }

    func testThirdPartyAppsNotProtected() {
        XCTAssertFalse(guard_.isProtectedApp("com.google.Chrome"))
        XCTAssertFalse(guard_.isProtectedApp("com.spotify.client"))
        XCTAssertFalse(guard_.isProtectedApp("com.microsoft.VSCode"))
    }

    // MARK: - Orphan Safety Policy Tests

    func testCacheOrphansAllowed() {
        let path = MCConstants.userCaches.appending(path: "com.removed.app")
        XCTAssertTrue(guard_.isSafeForOrphanDeletion(path))
    }

    func testLogOrphansAllowed() {
        let path = MCConstants.userLogs.appending(path: "RemovedApp.log")
        XCTAssertTrue(guard_.isSafeForOrphanDeletion(path))
    }

    func testPreferenceOrphansBlocked() {
        let path = MCConstants.userPreferences.appending(path: "com.removed.app.plist")
        XCTAssertFalse(guard_.isSafeForOrphanDeletion(path))
    }

    func testContainerOrphansBlocked() {
        let path = MCConstants.userContainers.appending(path: "com.removed.app")
        XCTAssertFalse(guard_.isSafeForOrphanDeletion(path))
    }
}

// MARK: - Scan Category Tests

final class ScanCategoryTests: XCTestCase {
    func testAllCategoriesHaveDisplayNames() {
        for category in ScanCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category) missing display name")
        }
    }

    func testAllCategoriesHaveIcons() {
        for category in ScanCategory.allCases {
            XCTAssertFalse(category.systemImage.isEmpty, "\(category) missing icon")
        }
    }

    func testAutoSelectDefaults() {
        XCTAssertTrue(ScanCategory.userCaches.autoSelect)
        XCTAssertTrue(ScanCategory.systemCaches.autoSelect)
        XCTAssertFalse(ScanCategory.unusedDiskImages.autoSelect)
        XCTAssertFalse(ScanCategory.largeFiles.autoSelect)
        XCTAssertFalse(ScanCategory.duplicates.autoSelect)
    }
}

// MARK: - File Item Tests

final class FileItemTests: XCTestCase {
    func testFormattedSize() {
        let item = FileItem(
            url: URL(filePath: "/tmp/test.txt"),
            name: "test.txt",
            size: 5 * 1024 * 1024,
            allocatedSize: 5 * 1024 * 1024,
            isDirectory: false
        )
        XCTAssertTrue(item.formattedSize.contains("5"))
    }

    func testFileExtension() {
        let item = FileItem(
            url: URL(filePath: "/tmp/test.log"),
            name: "test.log",
            size: 100,
            allocatedSize: 100,
            isDirectory: false
        )
        XCTAssertEqual(item.fileExtension, "log")
    }

    func testEqualityByURL() {
        let url = URL(filePath: "/tmp/same.txt")
        let a = FileItem(url: url, name: "same.txt", size: 100, allocatedSize: 100, isDirectory: false)
        let b = FileItem(url: url, name: "same.txt", size: 999, allocatedSize: 999, isDirectory: false)
        XCTAssertEqual(a, b)
    }

    func testInequalityByURL() {
        let a = FileItem(url: URL(filePath: "/a"), name: "a", size: 100, allocatedSize: 100, isDirectory: false)
        let b = FileItem(url: URL(filePath: "/b"), name: "b", size: 100, allocatedSize: 100, isDirectory: false)
        XCTAssertNotEqual(a, b)
    }
}

// MARK: - Scan Result Tests

final class ScanResultTests: XCTestCase {
    func testTotalSize() {
        let items = (0..<5).map {
            FileItem(url: URL(filePath: "/\($0)"), name: "\($0)", size: 100, allocatedSize: 100, isDirectory: false)
        }
        let result = ScanResult(category: .userCaches, items: items)
        XCTAssertEqual(result.totalSize, 500)
        XCTAssertEqual(result.fileCount, 5)
    }

    func testEmptyResult() {
        let result = ScanResult(category: .userCaches, items: [])
        XCTAssertEqual(result.totalSize, 0)
        XCTAssertEqual(result.fileCount, 0)
    }
}

// MARK: - Constants Tests

final class ConstantsTests: XCTestCase {
    func testProtectedPathsNotEmpty() {
        XCTAssertFalse(MCConstants.protectedPaths.isEmpty)
    }

    func testProtectedAppsNotEmpty() {
        XCTAssertFalse(MCConstants.protectedApps.isEmpty)
    }

    func testPreservedLanguagesContainEnglish() {
        XCTAssertTrue(MCConstants.preservedLanguages.contains("en.lproj"))
        XCTAssertTrue(MCConstants.preservedLanguages.contains("Base.lproj"))
    }

    func testPathsExistOrAreReasonable() {
        // These directories should exist on any Mac
        XCTAssertTrue(FileManager.default.fileExists(atPath: MCConstants.home.path(percentEncoded: false)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: MCConstants.userLibrary.path(percentEncoded: false)))
    }
}

// MARK: - Treemap Tests

final class TreemapTests: XCTestCase {
    func testEmptyLayout() {
        let rects = SquarifiedTreemap.layout(nodes: [], in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(rects.isEmpty)
    }

    func testSingleNodeFillsRect() {
        let node = TreemapNode(name: "root", size: 1000, url: URL(filePath: "/"), isDirectory: true, children: [])
        let rects = SquarifiedTreemap.layout(nodes: [node], in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(rects.count, 1)
    }

    func testMultipleNodes() {
        let nodes = [
            TreemapNode(name: "a", size: 500, url: URL(filePath: "/a"), isDirectory: true, children: []),
            TreemapNode(name: "b", size: 300, url: URL(filePath: "/b"), isDirectory: true, children: []),
            TreemapNode(name: "c", size: 200, url: URL(filePath: "/c"), isDirectory: true, children: []),
        ]
        let rects = SquarifiedTreemap.layout(nodes: nodes, in: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(rects.count, 3)
    }
}

// MARK: - App Path Finder Tests

final class AppPathFinderTests: XCTestCase {
    func testPatternGeneration() {
        let finder = AppPathFinder(maxLevel: .companyName)
        let app = AppInfo(
            bundleIdentifier: "com.google.Chrome",
            name: "Google Chrome",
            path: URL(filePath: "/Applications/Google Chrome.app")
        )
        let files = finder.findAssociatedFiles(for: app)
        // Should not crash; actual results depend on what's installed
        _ = files
    }

    func testAppleAppNotSearched() {
        let finder = AppPathFinder()
        let app = AppInfo(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            path: URL(filePath: "/Applications/Safari.app"),
            isAppleApp: true
        )
        // Should still work, just might find Apple files
        let files = finder.findAssociatedFiles(for: app)
        _ = files
    }
}

// MARK: - Volume Info Tests

final class VolumeInfoTests: XCTestCase {
    func testMountedVolumes() {
        let volumes = VolumeInfo.mountedVolumes()
        XCTAssertFalse(volumes.isEmpty, "Should find at least the root volume")
        if let root = volumes.first {
            XCTAssertGreaterThan(root.totalCapacity, 0)
            XCTAssertGreaterThan(root.availableCapacity, 0)
        }
    }
}

// MARK: - Maintenance Task Tests

final class MaintenanceTaskTests: XCTestCase {
    func testAllTasksHaveDescriptions() {
        for task in MaintenanceTask.allCases {
            XCTAssertFalse(task.description.isEmpty)
            XCTAssertFalse(task.icon.isEmpty)
        }
    }

    func testRootRequirements() {
        XCTAssertFalse(MaintenanceTask.freeUpRAM.requiresRoot)
        XCTAssertFalse(MaintenanceTask.speedUpMail.requiresRoot)
        XCTAssertTrue(MaintenanceTask.flushDNSCache.requiresRoot)
        XCTAssertTrue(MaintenanceTask.reindexSpotlight.requiresRoot)
    }
}

// MARK: - File Size Formatter Tests

final class FileSizeFormatterTests: XCTestCase {
    func testFormatBytes() {
        let result = FileSizeFormatter.format(1024)
        XCTAssertFalse(result.isEmpty)
    }

    func testShortFormat() {
        let result = FileSizeFormatter.shortFormat(1024 * 1024 * 100)
        XCTAssertFalse(result.value.isEmpty)
        XCTAssertFalse(result.unit.isEmpty)
    }

    func testZeroBytes() {
        let result = FileSizeFormatter.format(0)
        XCTAssertFalse(result.isEmpty)
    }
}
