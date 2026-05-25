import Foundation
import MacCleanKit
import OSLog

public actor CleaningEngine {
    public enum CleanMode: Sendable {
        case trash
        case permanent
        case dryRun
    }

    public struct CleanResult: Sendable {
        public let removedCount: Int
        public let freedBytes: UInt64
        public let errors: [CleanError]
        public let skippedCount: Int
    }

    public struct CleanError: Sendable {
        public let path: String
        public let error: String
    }

    private let safetyGuard = SafetyGuard()
    private let logger = Logger(subsystem: MCConstants.bundleIdentifier, category: "CleaningEngine")

    public init() {}

    public func clean(items: [FileItem], mode: CleanMode = .trash) async -> CleanResult {
        let urls = items.map(\.url)

        do {
            try safetyGuard.validateDeletion(paths: urls)
        } catch {
            logger.error("Safety validation failed: \(error.localizedDescription)")
            return CleanResult(
                removedCount: 0,
                freedBytes: 0,
                errors: [CleanError(path: "validation", error: error.localizedDescription)],
                skippedCount: items.count
            )
        }

        var removedCount = 0
        var freedBytes: UInt64 = 0
        var errors: [CleanError] = []
        var skippedCount = 0

        for item in items {
            if Task.isCancelled { break }

            do {
                try safetyGuard.validatePath(item.url)
            } catch {
                skippedCount += 1
                errors.append(CleanError(path: item.url.path(percentEncoded: false), error: error.localizedDescription))
                continue
            }

            switch mode {
            case .dryRun:
                removedCount += 1
                freedBytes += item.size
                logOperation(path: item.url, size: item.size, dryRun: true)

            case .trash:
                do {
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    removedCount += 1
                    freedBytes += item.size
                    logOperation(path: item.url, size: item.size, dryRun: false)
                } catch {
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false),
                        error: error.localizedDescription
                    ))
                }

            case .permanent:
                do {
                    try FileManager.default.removeItem(at: item.url)
                    removedCount += 1
                    freedBytes += item.size
                    logOperation(path: item.url, size: item.size, dryRun: false)
                } catch {
                    errors.append(CleanError(
                        path: item.url.path(percentEncoded: false),
                        error: error.localizedDescription
                    ))
                }
            }
        }

        logger.info("Cleaning complete: \(removedCount) removed, \(freedBytes) bytes freed, \(errors.count) errors")

        return CleanResult(
            removedCount: removedCount,
            freedBytes: freedBytes,
            errors: errors,
            skippedCount: skippedCount
        )
    }

    private nonisolated func logOperation(path: URL, size: UInt64, dryRun: Bool) {
        let fm = FileManager.default
        let logDir = MCConstants.operationLogDir
        let logFile = MCConstants.operationLogFile

        if !fm.fileExists(atPath: logDir.path(percentEncoded: false)) {
            try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = dryRun ? "[DRY-RUN]" : "[REMOVED]"
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        let line = "\(timestamp) \(prefix) \(path.path(percentEncoded: false)) (\(sizeStr))\n"

        if let data = line.data(using: .utf8) {
            if fm.fileExists(atPath: logFile.path(percentEncoded: false)) {
                if let handle = try? FileHandle(forWritingTo: logFile) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
    }
}
