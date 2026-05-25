import Foundation
import CryptoKit
import MacCleanKit

public struct DuplicatesModule: ScanModule {
    public let id = "duplicates"
    public let name = "Duplicates"
    public let category = ModuleCategory.files

    private let scanner = TargetedScanner()

    public init() {}

    public func scan() async -> [ScanResult] {
        let targets = [
            ScanTarget(
                path: MCConstants.home,
                recursive: true,
                maxDepth: 5,
                minSize: 1024, // Skip tiny files
                excludePatterns: ["Library", ".Trash", ".git", "node_modules", ".build"]
            ),
        ]

        let items = await scanner.scan(targets: targets)
        let files = items.filter { !$0.isDirectory }

        let duplicateGroups = await findDuplicates(files)

        var duplicateItems: [FileItem] = []
        for group in duplicateGroups {
            // Keep the first file (original), mark the rest as duplicates
            for item in group.dropFirst() {
                duplicateItems.append(item)
            }
        }

        guard !duplicateItems.isEmpty else { return [] }
        return [ScanResult(category: .duplicates, items: duplicateItems, autoSelect: false)]
    }

    // Progressive duplicate detection pipeline
    public func findDuplicates(_ files: [FileItem]) async -> [[FileItem]] {
        // Stage 1: Group by size (eliminates ~80-90%)
        let sizeGroups = Dictionary(grouping: files) { $0.size }
        let candidates = sizeGroups.values.filter { $0.count > 1 }

        // Stage 2: Partial hash (first 4KB)
        var partialHashGroups: [String: [FileItem]] = [:]
        for group in candidates {
            for item in group {
                if let hash = partialHash(item.url) {
                    let key = "\(item.size)-\(hash)"
                    partialHashGroups[key, default: []].append(item)
                }
            }
        }
        let partialCandidates = partialHashGroups.values.filter { $0.count > 1 }

        // Stage 3: Full hash (only for remaining candidates)
        var fullHashGroups: [String: [FileItem]] = [:]
        for group in partialCandidates {
            for item in group {
                if let hash = fullHash(item.url) {
                    fullHashGroups[hash, default: []].append(item)
                }
            }
        }

        // Stage 4: Filter out hard links (same inode)
        return fullHashGroups.values
            .filter { $0.count > 1 }
            .map { group in
                var seen: Set<UInt64> = []
                return group.filter { item in
                    if item.inode == 0 || seen.insert(item.inode).inserted {
                        return true
                    }
                    return false
                }
            }
            .filter { $0.count > 1 }
    }

    private func partialHash(_ url: URL, bytes: Int = 4096) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: bytes)
        guard !data.isEmpty else { return nil }

        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func fullHash(_ url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 65536) // 64KB chunks
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Duplicate Group Display

public struct DuplicateGroup: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let hash: String
    public let size: UInt64
    public let files: [FileItem]

    public var wastedSpace: UInt64 {
        size * UInt64(files.count - 1)
    }

    public var formattedWastedSpace: String {
        ByteCountFormatter.string(fromByteCount: Int64(wastedSpace), countStyle: .file)
    }
}
