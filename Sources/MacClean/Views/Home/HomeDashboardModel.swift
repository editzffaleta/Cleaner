import SwiftUI
import AppKit
import Darwin
import MacCleanKit

/// Gathers everything the Home dashboard shows: live system vitals, protection
/// status, a storage breakdown, and background estimates (recoverable junk,
/// updatable apps, heavy apps). Cheap poll every few seconds for the vitals;
/// the heavier estimates run once in the background and fill in when ready.
@MainActor
@Observable
final class HomeDashboardModel {
    var stats: SystemStatsCollector.SystemStats?
    var protection: SharedAppState.ProtectionStatus?
    var recoverableBytes: UInt64?
    var heavyAppsCount: Int?
    var updatableCount: Int?
    var storage: [StorageSlice] = []

    struct StorageSlice: Identifiable {
        let id = UUID()
        let label: String
        let bytes: UInt64
        let color: Color
    }

    private let collector = SystemStatsCollector()
    private var pollTask: Task<Void, Never>?
    private var didLoadHeavy = false

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { await pollLoop() }
        if !didLoadHeavy {
            didLoadHeavy = true
            Task { await loadEstimates() }
        }
    }

    func stop() { pollTask?.cancel(); pollTask = nil }

    private func pollLoop() async {
        while !Task.isCancelled {
            let s = await collector.collect()
            stats = s
            protection = SharedAppState.protectionStatus
            if storage.isEmpty { computeStorage(diskTotal: s.diskTotal, diskFree: s.diskFree) }
            heavyAppsCount = Self.countHeavyApps()
            try? await Task.sleep(for: .seconds(3))
        }
    }

    /// Background one-shots: recoverable junk (safe categories) and updatable apps.
    private func loadEstimates() async {
        if let bytes = await Self.estimateRecoverable() {
            recoverableBytes = bytes
        }
        if let count = await Self.estimateUpdatable() {
            updatableCount = count
        }
    }

    private func computeStorage(diskTotal: UInt64, diskFree: UInt64) {
        guard diskTotal > 0 else { return }
        Task.detached(priority: .utility) {
            // Only /Applications is scanned (no TCC prompt); user folders like
            // Documents/Downloads/Pictures are protected and would pop a
            // permission dialog on the Home screen, so the rest is bucketed as
            // "Sistema e outros".
            let apps = dirSizeCapped(URL(filePath: "/Applications"))
            let used = diskTotal > diskFree ? diskTotal - diskFree : 0
            let system = used > apps ? used - apps : 0
            let slices: [StorageSlice] = [
                .init(label: L10n.tr("系统与其他", "Sistema e outros"), bytes: system, color: Color(red: 0.35, green: 0.55, blue: 0.95)),
                .init(label: L10n.tr("应用", "Aplicativos"), bytes: apps, color: Color(red: 0.62, green: 0.42, blue: 0.92)),
                .init(label: L10n.tr("可用", "Livre"), bytes: diskFree, color: Color.white.opacity(0.22)),
            ].filter { $0.bytes > 0 }
            await MainActor.run { self.storage = slices }
        }
    }

    // MARK: - Estimates (nonisolated helpers)

    private static func estimateRecoverable() async -> UInt64? {
        let results = await SystemJunkModule().scan()
        let safe = results.filter { $0.autoSelect }
        return safe.reduce(0) { $0 + $1.totalSize }
    }

    private static func estimateUpdatable() async -> Int? {
        let results = await UpdaterModule().scan()
        return results.reduce(0) { $0 + $1.fileCount }
    }

    /// Count of foreground apps using more than ~1 GB of memory.
    static func countHeavyApps(thresholdBytes: UInt64 = 1_073_741_824) -> Int {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .reduce(0) { acc, app in
                guard app.processIdentifier > 0,
                      let mem = physFootprint(pid: app.processIdentifier),
                      mem >= thresholdBytes else { return acc }
                return acc + 1
            }
    }

    private static func physFootprint(pid: Int32) -> UInt64? {
        var info = rusage_info_current()
        let rc = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard rc == 0 else { return nil }
        return info.ri_phys_footprint
    }
}

/// Directory size with a hard file-count budget so it never hangs on a huge
/// tree (e.g. a Photos library). Approximate by design — for the storage bar.
func dirSizeCapped(_ url: URL, maxFiles: Int = 60_000) -> UInt64 {
    let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey]
    guard let en = FileManager.default.enumerator(
        at: url, includingPropertiesForKeys: Array(keys),
        options: [.skipsHiddenFiles], errorHandler: { _, _ in true }
    ) else { return 0 }
    var total: UInt64 = 0
    var count = 0
    for case let f as URL in en {
        count += 1
        if count > maxFiles { break }
        if let v = try? f.resourceValues(forKeys: keys),
           v.isRegularFile == true, let s = v.totalFileAllocatedSize {
            total += UInt64(s)
        }
    }
    return total
}
