import XCTest
import Foundation
@testable import MacCleanKit

final class MaintenanceTaskTests: XCTestCase {

    func testTenTasksExist() {
        XCTAssertEqual(MaintenanceTask.allCases.count, 10)
    }

    func testAllTasksHaveDescriptionAndIcon() {
        for task in MaintenanceTask.allCases {
            XCTAssertFalse(task.description.isEmpty, "\(task) missing description")
            XCTAssertFalse(task.icon.isEmpty, "\(task) missing icon")
            XCTAssertFalse(task.rawValue.isEmpty, "\(task) missing display name")
        }
    }

    func testRootRequirements() {
        XCTAssertFalse(MaintenanceTask.freeUpRAM.requiresRoot, "purge runs as user")
        XCTAssertFalse(MaintenanceTask.speedUpMail.requiresRoot, "Mail reindex doesn't need root")
        XCTAssertTrue(MaintenanceTask.flushDNSCache.requiresRoot)
        XCTAssertTrue(MaintenanceTask.reindexSpotlight.requiresRoot)
        XCTAssertTrue(MaintenanceTask.repairDiskPermissions.requiresRoot)
        XCTAssertTrue(MaintenanceTask.rebuildLaunchServices.requiresRoot)
        XCTAssertTrue(MaintenanceTask.thinTimeMachineSnapshots.requiresRoot)
    }

    func testSystemCommandsResolveCorrectly() {
        XCTAssertEqual(MaintenanceTask.freeUpRAM.systemCommand?.executable, "/usr/bin/purge")
        XCTAssertEqual(MaintenanceTask.flushDNSCache.systemCommand?.executable, "/usr/bin/dscacheutil")
        XCTAssertEqual(MaintenanceTask.flushDNSCache.systemCommand?.arguments, ["-flushcache"])
        XCTAssertEqual(MaintenanceTask.reindexSpotlight.systemCommand?.executable, "/usr/bin/mdutil")
    }

    func testSpeedUpMailHasNoSystemCommand() {
        XCTAssertNil(MaintenanceTask.speedUpMail.systemCommand,
                     "Mail reindex is custom logic, not a Process invocation")
    }

    func testAllSystemCommandsArePresentExceptMail() {
        for task in MaintenanceTask.allCases {
            if task == .speedUpMail {
                XCTAssertNil(task.systemCommand)
            } else {
                XCTAssertNotNil(task.systemCommand, "\(task) should have a system command")
            }
        }
    }

    func testIdentifiableConformance() {
        XCTAssertEqual(MaintenanceTask.freeUpRAM.id, "Free Up RAM")
    }

    func testAllExecutablePathsAreAbsolute() {
        for task in MaintenanceTask.allCases {
            if let cmd = task.systemCommand {
                XCTAssertTrue(cmd.executable.hasPrefix("/"),
                              "\(task) executable path must be absolute (got: \(cmd.executable))")
            }
        }
    }
}
