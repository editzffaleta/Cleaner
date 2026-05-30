import Foundation

/// The set of maintenance tasks Mac Clean knows how to run. Pure data — the
/// actual `Process` execution happens in `MaintenanceExecutor` in the
/// MacClean target.
public enum MaintenanceTask: String, CaseIterable, Identifiable, Sendable {
    case freeUpRAM = "Free Up RAM"
    case freeUpPurgeableSpace = "Free Up Purgeable Space"
    case runMaintenanceScripts = "Run Maintenance Scripts"
    case repairDiskPermissions = "Repair Disk Permissions"
    case verifyStartupDisk = "Verify Startup Disk"
    case speedUpMail = "Speed Up Mail"
    case rebuildLaunchServices = "Rebuild Launch Services"
    case reindexSpotlight = "Reindex Spotlight"
    case flushDNSCache = "Flush DNS Cache"
    case thinTimeMachineSnapshots = "Thin Time Machine Snapshots"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .freeUpRAM: "memorychip"
        case .freeUpPurgeableSpace: "internaldrive"
        case .runMaintenanceScripts: "terminal"
        case .repairDiskPermissions: "lock.shield"
        case .verifyStartupDisk: "checkmark.shield"
        case .speedUpMail: "envelope"
        case .rebuildLaunchServices: "arrow.triangle.2.circlepath"
        case .reindexSpotlight: "magnifyingglass"
        case .flushDNSCache: "network"
        case .thinTimeMachineSnapshots: "clock.arrow.circlepath"
        }
    }

    public var description: String {
        switch self {
        case .freeUpRAM:
            "Purge inactive memory to give active apps more breathing room"
        case .freeUpPurgeableSpace:
            "Remove temporary system files and Time Machine snapshots marked as purgeable"
        case .runMaintenanceScripts:
            "Execute macOS built-in daily, weekly, and monthly maintenance routines"
        case .repairDiskPermissions:
            "Verify and restore file permissions corrupted by improper shutdowns"
        case .verifyStartupDisk:
            "Check file system integrity of the boot disk"
        case .speedUpMail:
            "Reindex the Mail.app database to fix search and performance issues"
        case .rebuildLaunchServices:
            "Repair Finder's file-type-to-application mapping database"
        case .reindexSpotlight:
            "Rebuild the Spotlight search index for improved search accuracy"
        case .flushDNSCache:
            "Clear the local DNS cache and force fresh lookups"
        case .thinTimeMachineSnapshots:
            "Reduce local Time Machine snapshot sizes to reclaim disk space"
        }
    }

    public var requiresRoot: Bool {
        switch self {
        case .freeUpRAM, .speedUpMail: false
        default: true
        }
    }

    /// The system executable + arguments that implement this task.
    /// Pure data — the MacClean target's `MaintenanceExecutor` uses this
    /// to invoke `Process`. Tasks that aren't a simple command (e.g., Mail
    /// reindex which deletes a specific file) return `nil`.
    public var systemCommand: (executable: String, arguments: [String])? {
        switch self {
        case .freeUpRAM:
            ("/usr/bin/purge", [])
        case .freeUpPurgeableSpace:
            ("/usr/sbin/diskutil", ["apfs", "listSnapshots", "/"])
        case .runMaintenanceScripts:
            ("/usr/sbin/periodic", ["daily", "weekly", "monthly"])
        case .repairDiskPermissions:
            ("/usr/sbin/diskutil", ["repairPermissions", "/"])
        case .verifyStartupDisk:
            ("/usr/sbin/diskutil", ["verifyVolume", "/"])
        case .speedUpMail:
            nil
        case .rebuildLaunchServices:
            ("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
             ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"])
        case .reindexSpotlight:
            ("/usr/bin/mdutil", ["-E", "/"])
        case .flushDNSCache:
            ("/usr/bin/dscacheutil", ["-flushcache"])
        case .thinTimeMachineSnapshots:
            ("/usr/bin/tmutil", ["thinlocalsnapshots", "/", "999999999999", "4"])
        }
    }
}
