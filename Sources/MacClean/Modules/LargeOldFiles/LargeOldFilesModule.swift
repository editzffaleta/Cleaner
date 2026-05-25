import Foundation
import MacCleanKit

public struct LargeOldFilesModule: ScanModule {
    public let id = "large_old_files"
    public let name = "Large & Old Files"
    public let category = ModuleCategory.files

    private let scanner = TargetedScanner()
    private let minSize: UInt64
    private let minAge: TimeInterval?

    public init(minSize: UInt64 = 50 * 1024 * 1024, minAge: TimeInterval? = nil) {
        self.minSize = minSize
        self.minAge = minAge
    }

    public func scan() async -> [ScanResult] {
        let targets = [
            ScanTarget(
                path: MCConstants.home,
                recursive: true,
                maxDepth: 5,
                minAge: minAge,
                minSize: minSize,
                excludePatterns: ["Library", ".Trash", ".git", "node_modules"]
            ),
            ScanTarget(
                path: MCConstants.downloads,
                recursive: true,
                minAge: minAge,
                minSize: minSize
            ),
        ]

        let items = await scanner.scan(targets: targets)

        var largeItems: [FileItem] = []
        var oldItems: [FileItem] = []

        let sixMonthsAgo = Date().addingTimeInterval(-180 * 24 * 3600)

        for item in items where !item.isDirectory {
            if item.size >= minSize {
                largeItems.append(item)
            }
            if let modDate = item.modificationDate, modDate < sixMonthsAgo {
                oldItems.append(item)
            }
        }

        largeItems.sort { $0.size > $1.size }
        oldItems.sort { ($0.modificationDate ?? .distantFuture) < ($1.modificationDate ?? .distantFuture) }

        var results: [ScanResult] = []
        if !largeItems.isEmpty {
            results.append(ScanResult(category: .largeFiles, items: largeItems, autoSelect: false))
        }
        if !oldItems.isEmpty {
            results.append(ScanResult(category: .oldFiles, items: oldItems, autoSelect: false))
        }
        return results
    }
}

// MARK: - File grouping helpers

public enum FileGroup {
    case byType
    case bySize
    case byAge

    public func group(_ items: [FileItem]) -> [(String, [FileItem])] {
        switch self {
        case .byType:
            groupByType(items)
        case .bySize:
            groupBySize(items)
        case .byAge:
            groupByAge(items)
        }
    }

    private func groupByType(_ items: [FileItem]) -> [(String, [FileItem])] {
        var groups: [String: [FileItem]] = [:]
        for item in items {
            let type = fileTypeLabel(item.fileExtension)
            groups[type, default: []].append(item)
        }
        return groups.sorted { $0.key < $1.key }
    }

    private func groupBySize(_ items: [FileItem]) -> [(String, [FileItem])] {
        var groups: [String: [FileItem]] = [
            "1 GB+": [],
            "500 MB - 1 GB": [],
            "100 - 500 MB": [],
            "50 - 100 MB": [],
        ]
        for item in items {
            let mb = item.size / (1024 * 1024)
            if mb >= 1024 {
                groups["1 GB+"]?.append(item)
            } else if mb >= 500 {
                groups["500 MB - 1 GB"]?.append(item)
            } else if mb >= 100 {
                groups["100 - 500 MB"]?.append(item)
            } else {
                groups["50 - 100 MB"]?.append(item)
            }
        }
        return groups.filter { !$0.value.isEmpty }.sorted { $0.key > $1.key }
    }

    private func groupByAge(_ items: [FileItem]) -> [(String, [FileItem])] {
        var groups: [String: [FileItem]] = [:]
        let now = Date()
        for item in items {
            guard let modDate = item.modificationDate else { continue }
            let days = Int(now.timeIntervalSince(modDate) / (24 * 3600))
            let label: String
            if days > 365 { label = "Over 1 year" }
            else if days > 180 { label = "6 months - 1 year" }
            else if days > 90 { label = "3 - 6 months" }
            else if days > 30 { label = "1 - 3 months" }
            else { label = "Last month" }
            groups[label, default: []].append(item)
        }
        return groups.sorted { $0.key > $1.key }
    }

    private func fileTypeLabel(_ ext: String) -> String {
        switch ext {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv": "Videos"
        case "mp3", "wav", "flac", "aac", "m4a", "ogg": "Audio"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "raw": "Images"
        case "pdf": "PDFs"
        case "doc", "docx", "pages", "rtf", "txt": "Documents"
        case "xls", "xlsx", "numbers", "csv": "Spreadsheets"
        case "zip", "gz", "tar", "rar", "7z", "bz2": "Archives"
        case "dmg", "iso", "img": "Disk Images"
        case "app": "Applications"
        case "pkg", "mpkg": "Installers"
        default: "Other"
        }
    }
}
