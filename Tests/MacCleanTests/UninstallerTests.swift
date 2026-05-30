import XCTest
import Foundation
@testable import MacClean
@testable import MacCleanKit
import MacCleanTestSupport

/// Tests for the system-side AppDiscovery + AppPathFinder wrappers.
/// Pure matching logic is tested in MacCleanKitTests/AppMatchingTests.
final class UninstallerTests: XCTestCase {

    func testAppDiscoveryFindsSyntheticApp() async throws {
        // Create a fake .app under user's ~/Applications, run discovery,
        // verify it shows up.
        let myApps = MCConstants.home.appending(path: "Applications")
        try FileManager.default.createDirectory(at: myApps, withIntermediateDirectories: true)

        let uniqueName = "MacCleanTestApp-\(UUID().uuidString.prefix(8))"
        let appPath = myApps.appending(path: "\(uniqueName).app")
        defer { try? FileManager.default.removeItem(at: appPath) }

        try TestFixtures.writeFakeApp(
            at: appPath,
            bundleIdentifier: "com.test.macclean.\(uniqueName)",
            name: uniqueName,
            version: "1.0"
        )

        let apps = await AppDiscovery().discoverApps()
        let ours = apps.first { $0.name == uniqueName }
        XCTAssertNotNil(ours, "Discovery should find our synthetic .app at \(appPath.path(percentEncoded: false))")
        XCTAssertEqual(ours?.bundleIdentifier, "com.test.macclean.\(uniqueName)")
    }

    func testAppPathFinderUsesAppMatching() {
        // AppPathFinder is a thin wrapper around AppMatching; just verify
        // the type-alias / instantiation path works.
        let finder = AppPathFinder(maxLevel: .companyName)
        XCTAssertEqual(finder.maxLevel, AppMatching.MatchLevel.companyName)
    }
}
