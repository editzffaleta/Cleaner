import Foundation
import AppKit
import MacCleanKit

struct BrokenPreferencesCategory: JunkCategory {
    let scanCategory = ScanCategory.brokenPreferences

    var targets: [ScanTarget] {
        [
            ScanTarget(
                path: MCConstants.userPreferences,
                recursive: false,
                fileExtensions: ["plist"]
            ),
        ]
    }

    func filterBrokenPlists(_ items: [FileItem]) -> [FileItem] {
        items.filter { item in
            guard item.fileExtension == "plist" else { return false }

            // Check 1: Can the plist be deserialized?
            guard let data = try? Data(contentsOf: item.url) else { return true }

            do {
                _ = try PropertyListSerialization.propertyList(from: data, format: nil)
            } catch {
                return true // Corrupted plist
            }

            // Check 2: Does the bundle ID reference an installed app?
            let bundleID = item.url.deletingPathExtension().lastPathComponent
            if bundleID.contains(".") {
                let appExists = appExistsForBundleID(bundleID)
                if !appExists {
                    return true // Orphaned preference
                }
            }

            return false
        }
    }

    private func appExistsForBundleID(_ bundleID: String) -> Bool {
        // Check if any app with this bundle ID is installed
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
            return true
        }

        // Also check containers
        let containerPath = MCConstants.userContainers.appending(path: bundleID)
        if FileManager.default.fileExists(atPath: containerPath.path(percentEncoded: false)) {
            return true
        }

        return false
    }
}
