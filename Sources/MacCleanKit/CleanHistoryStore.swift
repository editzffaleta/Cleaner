import Foundation

/// One recorded clean operation, shown in the Cleanup History screen.
public struct CleanHistoryEntry: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let date: Date
    public let freedBytes: UInt64
    public let removedCount: Int
    /// Where the clean came from — see `CleanHistorySource`.
    public let source: String

    public init(id: UUID = UUID(), date: Date, freedBytes: UInt64, removedCount: Int, source: String) {
        self.id = id
        self.date = date
        self.freedBytes = freedBytes
        self.removedCount = removedCount
        self.source = source
    }
}

/// Stable identifiers for where a clean was initiated.
public enum CleanHistorySource {
    public static let smartScan = "smart-scan"
    public static let systemJunk = "system-junk"
    public static let duplicates = "duplicates"
    public static let uninstaller = "uninstaller"
    public static let scheduled = "scheduled"
    public static let widget = "widget"
    public static let manual = "manual"
}

/// Append-only JSON log of clean operations. Small volume (one entry per
/// clean), capped at `maxEntries`, so a flat JSON file is simpler and cheaper
/// than a DB table. Thread-safe via an internal lock; every clean path records
/// through `record(...)`.
public enum CleanHistoryStore {
    private static let maxEntries = 1000
    private static let lock = NSLock()

    /// Record a completed clean. No-ops when nothing was actually freed/removed
    /// so dry-runs and empty cleans don't clutter the history.
    public static func record(freedBytes: UInt64, removedCount: Int, source: String, date: Date = Date()) {
        guard freedBytes > 0 || removedCount > 0 else { return }
        lock.lock(); defer { lock.unlock() }
        var entries = loadLocked()
        entries.append(CleanHistoryEntry(date: date, freedBytes: freedBytes, removedCount: removedCount, source: source))
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
        saveLocked(entries)
    }

    /// All entries, newest first.
    public static func all() -> [CleanHistoryEntry] {
        lock.lock(); defer { lock.unlock() }
        return loadLocked().sorted { $0.date > $1.date }
    }

    public static func totalFreed() -> UInt64 {
        all().reduce(0) { $0 + $1.freedBytes }
    }

    public static func totalRemoved() -> Int {
        all().reduce(0) { $0 + $1.removedCount }
    }

    public static func clear() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: MCConstants.cleanHistoryFile)
    }

    // MARK: - Storage (call sites already hold `lock`)

    private static func loadLocked() -> [CleanHistoryEntry] {
        guard let data = try? Data(contentsOf: MCConstants.cleanHistoryFile) else { return [] }
        return (try? JSONDecoder().decode([CleanHistoryEntry].self, from: data)) ?? []
    }

    private static func saveLocked(_ entries: [CleanHistoryEntry]) {
        try? FileManager.default.createDirectory(
            at: MCConstants.operationLogDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: MCConstants.cleanHistoryFile, options: .atomic)
        }
    }
}
