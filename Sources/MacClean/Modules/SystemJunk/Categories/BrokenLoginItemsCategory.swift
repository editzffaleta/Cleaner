import Foundation
import AppKit
import MacCleanKit

struct BrokenLoginItemsCategory: JunkCategory {
    let scanCategory = ScanCategory.brokenLoginItems

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userLaunchAgents,
                recursive: false,
                fileExtensions: ["plist"]
            ),
        ]
    }

    func filterBrokenLoginItems(_ items: [FileItem]) -> [FileItem] {
        items.filter { item in
            guard item.fileExtension == "plist" else { return false }
            guard let data = try? Data(contentsOf: item.url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { return true } // Can't parse = broken

            // Extract the program path
            let programPath: String?
            if let prog = plist["Program"] as? String {
                programPath = prog
            } else if let args = plist["ProgramArguments"] as? [String], let first = args.first {
                programPath = first
            } else {
                programPath = nil
            }

            // If the program path points to a deleted app/binary, it's broken
            if let path = programPath {
                if !FileManager.default.fileExists(atPath: path) {
                    return true // Target binary doesn't exist
                }

                // Check if it references an app bundle that no longer exists
                if path.contains(".app/") {
                    let appPath = path.components(separatedBy: ".app/").first.map { $0 + ".app" }
                    if let appPath, !FileManager.default.fileExists(atPath: appPath) {
                        return true // Parent .app bundle is gone
                    }
                }
            }

            // Check bundle identifier reference
            if let label = plist["Label"] as? String, label.contains(".") {
                // If it looks like a bundle ID and no matching app exists
                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: label) == nil {
                    // Only flag if the program binary is also missing
                    if let path = programPath, !FileManager.default.fileExists(atPath: path) {
                        return true
                    }
                }
            }

            return false
        }
    }
}
