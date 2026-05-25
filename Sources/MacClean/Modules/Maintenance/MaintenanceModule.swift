import Foundation
import MacCleanKit

public struct MaintenanceModule: ScanModule {
    public let id = "maintenance"
    public let name = "Maintenance"
    public let category = ModuleCategory.performance

    public init() {}

    public func scan() async -> [ScanResult] {
        // Maintenance tasks don't scan files — they run system commands.
        // Return empty; the view drives task execution directly.
        []
    }
}

// MARK: - Maintenance Tasks

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
        case .freeUpRAM, .speedUpMail:
            false
        default:
            true
        }
    }
}

// MARK: - Maintenance Executor

public actor MaintenanceExecutor {
    public struct TaskResult: Sendable {
        public let task: MaintenanceTask
        public let success: Bool
        public let output: String
        public let error: String?
    }

    public init() {}

    public func execute(_ task: MaintenanceTask) async -> TaskResult {
        let command: String
        let args: [String]

        switch task {
        case .freeUpRAM:
            command = "/usr/bin/purge"
            args = []
        case .freeUpPurgeableSpace:
            command = "/usr/sbin/diskutil"
            args = ["apfs", "listSnapshots", "/"]
        case .runMaintenanceScripts:
            command = "/usr/sbin/periodic"
            args = ["daily", "weekly", "monthly"]
        case .repairDiskPermissions:
            command = "/usr/sbin/diskutil"
            args = ["repairPermissions", "/"]
        case .verifyStartupDisk:
            command = "/usr/sbin/diskutil"
            args = ["verifyVolume", "/"]
        case .speedUpMail:
            return await reindexMail()
        case .rebuildLaunchServices:
            command = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
            args = ["-kill", "-r", "-domain", "local", "-domain", "system", "-domain", "user"]
        case .reindexSpotlight:
            command = "/usr/bin/mdutil"
            args = ["-E", "/"]
        case .flushDNSCache:
            command = "/usr/bin/dscacheutil"
            args = ["-flushcache"]
        case .thinTimeMachineSnapshots:
            command = "/usr/bin/tmutil"
            args = ["thinlocalsnapshots", "/", "999999999999", "4"]
        }

        return await runProcess(task: task, command: command, args: args)
    }

    private func runProcess(task: MaintenanceTask, command: String, args: [String]) async -> TaskResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(filePath: command)
        process.arguments = args
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8)

            return TaskResult(
                task: task,
                success: process.terminationStatus == 0,
                output: output,
                error: error?.isEmpty == true ? nil : error
            )
        } catch {
            return TaskResult(
                task: task,
                success: false,
                output: "",
                error: error.localizedDescription
            )
        }
    }

    private func reindexMail() async -> TaskResult {
        let mailEnvelopeIndex = MCConstants.mailData
            .appending(path: "V10/MailData/Envelope Index")

        let fm = FileManager.default
        if fm.fileExists(atPath: mailEnvelopeIndex.path(percentEncoded: false)) {
            do {
                try fm.removeItem(at: mailEnvelopeIndex)
                return TaskResult(
                    task: .speedUpMail,
                    success: true,
                    output: "Mail envelope index removed. Mail will rebuild it on next launch.",
                    error: nil
                )
            } catch {
                return TaskResult(
                    task: .speedUpMail,
                    success: false,
                    output: "",
                    error: error.localizedDescription
                )
            }
        }

        return TaskResult(
            task: .speedUpMail,
            success: true,
            output: "Mail envelope index not found — Mail may use a different version directory.",
            error: nil
        )
    }
}
