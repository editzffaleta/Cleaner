import Foundation
import AppKit
import MacCleanKit

public struct UpdaterModule: ScanModule {
    public let id = "updater"
    public let name = "Updater"
    public let category = ModuleCategory.applications

    public init() {}

    public func scan() async -> [ScanResult] {
        []
    }
}

// MARK: - App Update Checker

public actor AppUpdateChecker {
    public struct AppUpdate: Identifiable, Sendable {
        public let id: UUID = UUID()
        public let app: AppInfo
        public let currentVersion: String
        public let availableVersion: String?
        public let updateSize: UInt64?
        public let hasUpdate: Bool
    }

    public init() {}

    public func checkForUpdates(apps: [AppInfo]) async -> [AppUpdate] {
        await withTaskGroup(of: AppUpdate?.self) { group in
            for app in apps where !app.isAppleApp {
                group.addTask {
                    await self.checkApp(app)
                }
            }

            var updates: [AppUpdate] = []
            for await update in group {
                if let update, update.hasUpdate {
                    updates.append(update)
                }
            }
            return updates.sorted { $0.app.name < $1.app.name }
        }
    }

    private func checkApp(_ app: AppInfo) async -> AppUpdate? {
        // Check for Sparkle-based update feeds
        let infoPlistURL = app.path.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        // Look for SUFeedURL (Sparkle update feed)
        guard let feedURLString = plist["SUFeedURL"] as? String,
              let feedURL = URL(string: feedURLString)
        else { return nil }

        // Fetch and parse the appcast XML
        guard let (data, _) = try? await URLSession.shared.data(from: feedURL) else { return nil }

        let parser = AppcastParser()
        let latestVersion = parser.parseLatestVersion(from: data)

        let currentVersion = app.version ?? "0"
        let hasUpdate = latestVersion != nil && latestVersion != currentVersion

        return AppUpdate(
            app: app,
            currentVersion: currentVersion,
            availableVersion: latestVersion,
            updateSize: nil,
            hasUpdate: hasUpdate
        )
    }
}

// MARK: - Simple Appcast XML Parser

final class AppcastParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private var latestVersion: String?
    private var currentElement = ""
    private var inItem = false

    func parseLatestVersion(from data: Data) -> String? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return latestVersion
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
        }
        if elementName == "enclosure", inItem {
            if let version = attributes["sparkle:shortVersionString"] ?? attributes["sparkle:version"] {
                if latestVersion == nil {
                    latestVersion = version
                }
            }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        if elementName == "item" {
            inItem = false
        }
    }
}
