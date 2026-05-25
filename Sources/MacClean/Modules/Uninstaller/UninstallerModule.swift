import Foundation
import AppKit
import MacCleanKit

public struct UninstallerModule: ScanModule {
    public let id = "uninstaller"
    public let name = "Uninstaller"
    public let category = ModuleCategory.applications

    public init() {}

    public func scan() async -> [ScanResult] {
        // The uninstaller doesn't produce traditional scan results.
        // It provides an app list with associated files.
        []
    }
}

// MARK: - App Discovery

public actor AppDiscovery {
    private let resourceKeys: [URLResourceKey] = [
        .fileSizeKey, .totalFileAllocatedSizeKey, .isApplicationKey,
        .contentModificationDateKey,
    ]

    public init() {}

    public func discoverApps() -> [AppInfo] {
        var apps: [AppInfo] = []
        let fm = FileManager.default

        let appDirs = [
            URL(filePath: "/Applications"),
            MCConstants.home.appending(path: "Applications"),
        ]

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: resourceKeys
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                if let info = appInfo(from: url) {
                    apps.append(info)
                }
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func appInfo(from url: URL) -> AppInfo? {
        let infoPlistURL = url.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        let bundleID = plist["CFBundleIdentifier"] as? String ?? ""
        let name = plist["CFBundleName"] as? String
            ?? plist["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let version = plist["CFBundleShortVersionString"] as? String

        let isApple = bundleID.hasPrefix("com.apple.")
        let size = directorySize(url)

        return AppInfo(
            bundleIdentifier: bundleID,
            name: name,
            path: url,
            version: version,
            size: size,
            lastOpened: lastOpenedDate(url),
            isAppleApp: isApple
        )
    }

    private func lastOpenedDate(_ url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.contentAccessDateKey])
        return values?.contentAccessDate
    }

    private func directorySize(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += UInt64(values?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}

// MARK: - 10-Level App Path Finder

public struct AppPathFinder: Sendable {
    public enum MatchLevel: Int, CaseIterable, Sendable {
        case bundleIDExact = 1       // com.google.Chrome
        case displayName = 2        // "Google Chrome"
        case appDirName = 3         // "Google Chrome.app"
        case normalizedName = 4     // "googlechrome"
        case bundleIDComponents = 5 // "google.Chrome"
        case baseBundleID = 6       // strip .helper, .agent, .daemon
        case versionStripped = 7    // remove version numbers
        case companyName = 8        // "google"
        case teamIdentifier = 9    // from code signature
        case entitlements = 10     // from code signing entitlements
    }

    public let maxLevel: MatchLevel

    public init(maxLevel: MatchLevel = .companyName) {
        self.maxLevel = maxLevel
    }

    private static let librarySubdirectories: [String] = [
        "Application Support", "Caches", "Containers", "Group Containers",
        "Preferences", "Logs", "Application Scripts", "Cookies",
        "HTTPStorages", "LaunchAgents", "Saved Application State",
        "Internet Plug-Ins", "PreferencePanes", "PrivilegedHelperTools",
        "Services", "WebKit", "Frameworks",
    ]

    public func findAssociatedFiles(for app: AppInfo) -> [FileItem] {
        let patterns = generatePatterns(for: app)
        var found: [FileItem] = []
        let fm = FileManager.default

        for subdir in Self.librarySubdirectories {
            let dirURL = MCConstants.userLibrary.appending(path: subdir)
            guard let contents = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: [
                .fileSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey,
            ]) else { continue }

            for itemURL in contents {
                let itemName = itemURL.lastPathComponent.lowercased()
                if patterns.contains(where: { itemName.contains($0) }) {
                    if let fileItem = makeFileItem(from: itemURL) {
                        found.append(fileItem)
                    }
                }
            }
        }

        // Also check system Library for launch daemons
        let systemDirs = [MCConstants.systemLaunchDaemons, MCConstants.systemLaunchAgents]
        for dirURL in systemDirs {
            guard let contents = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
            else { continue }

            for itemURL in contents where itemURL.pathExtension == "plist" {
                let itemName = itemURL.lastPathComponent.lowercased()
                if patterns.contains(where: { itemName.contains($0) }) {
                    if let fileItem = makeFileItem(from: itemURL) {
                        found.append(fileItem)
                    }
                }
            }
        }

        return found
    }

    private func generatePatterns(for app: AppInfo) -> Set<String> {
        var patterns: Set<String> = []
        let levels = MatchLevel.allCases.filter { $0.rawValue <= maxLevel.rawValue }

        for level in levels {
            switch level {
            case .bundleIDExact:
                patterns.insert(app.bundleIdentifier.lowercased())

            case .displayName:
                patterns.insert(app.name.lowercased())

            case .appDirName:
                let dirName = app.path.deletingPathExtension().lastPathComponent.lowercased()
                patterns.insert(dirName)

            case .normalizedName:
                let normalized = app.name.lowercased().filter(\.isLetter)
                if normalized.count >= 3 {
                    patterns.insert(normalized)
                }

            case .bundleIDComponents:
                let components = app.bundleIdentifier.components(separatedBy: ".")
                if components.count >= 2 {
                    let last2 = components.suffix(2).joined(separator: ".").lowercased()
                    patterns.insert(last2)
                }

            case .baseBundleID:
                var baseID = app.bundleIdentifier.lowercased()
                for suffix in [".helper", ".agent", ".daemon", ".launcher", ".updater"] {
                    if baseID.hasSuffix(suffix) {
                        baseID = String(baseID.dropLast(suffix.count))
                    }
                }
                patterns.insert(baseID)

            case .versionStripped:
                let stripped = app.name.replacingOccurrences(
                    of: "\\d+(\\.\\d+)*",
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespaces).lowercased()
                if stripped.count >= 3 {
                    patterns.insert(stripped)
                }

            case .companyName:
                let components = app.bundleIdentifier.components(separatedBy: ".")
                if components.count >= 2 {
                    let company = components[1].lowercased()
                    if company.count >= 3 && company != "apple" {
                        patterns.insert(company)
                    }
                }

            case .teamIdentifier:
                // Would require Security.framework code signing APIs
                break

            case .entitlements:
                // Would require Security.framework entitlement reading
                break
            }
        }

        return patterns
    }

    private func makeFileItem(from url: URL) -> FileItem? {
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey, .totalFileAllocatedSizeKey, .isDirectoryKey,
            .contentModificationDateKey, .nameKey,
        ])
        let isDir = values?.isDirectory ?? false
        var size = UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)

        if isDir {
            size = directorySize(url)
        }

        return FileItem(
            url: url,
            name: values?.name ?? url.lastPathComponent,
            size: size,
            allocatedSize: size,
            isDirectory: isDir,
            modificationDate: values?.contentModificationDate
        )
    }

    private func directorySize(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: []
        ) else { return 0 }

        var total: UInt64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            let v = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += UInt64(v?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
