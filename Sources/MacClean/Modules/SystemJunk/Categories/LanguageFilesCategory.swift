import Foundation
import MacCleanKit

struct LanguageFilesCategory: JunkCategory {
    let scanCategory = ScanCategory.languageFiles

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: URL(filePath: "/Applications"),
                recursive: true,
                fileExtensions: ["lproj"],
                excludePatterns: Array(MCConstants.preservedLanguages)
            ),
        ]
    }
}
