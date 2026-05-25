import Foundation
import MacCleanKit

public struct SystemJunkModule: ScanModule {
    public let id = "system_junk"
    public let name = "System Junk"
    public let category = ModuleCategory.cleanup

    private let scanner = TargetedScanner()

    public init() {}

    public func scan() async -> [ScanResult] {
        let categories: [JunkCategory] = [
            UserCacheCategory(),
            SystemCacheCategory(),
            UserLogCategory(),
            SystemLogCategory(),
            LanguageFilesCategory(),
            BrokenPreferencesCategory(),
            BrokenLoginItemsCategory(),
            DocumentVersionsCategory(),
            BrokenDownloadsCategory(),
            IOSDeviceBackupsCategory(),
            OldUpdatesCategory(),
            UniversalBinariesCategory(),
            XcodeJunkCategory(),
            DeletedUsersCategory(),
            UnusedDiskImagesCategory(),
            IncompleteDownloadsCategory(),
        ]

        return await withTaskGroup(of: ScanResult?.self) { group in
            for cat in categories {
                group.addTask {
                    let items = await scanner.scan(targets: cat.targets)
                    guard !items.isEmpty else { return nil }
                    return ScanResult(
                        category: cat.scanCategory,
                        items: items,
                        autoSelect: cat.scanCategory.autoSelect
                    )
                }
            }

            var results: [ScanResult] = []
            for await result in group {
                if let result {
                    results.append(result)
                }
            }
            return results.sorted { $0.totalSize > $1.totalSize }
        }
    }
}
