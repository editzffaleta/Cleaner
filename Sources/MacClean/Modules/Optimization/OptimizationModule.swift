import Foundation
import AppKit
import MacCleanKit

public struct OptimizationModule: ScanModule {
    public let id = "optimization"
    public let name = "Optimization"
    public let category = ModuleCategory.performance

    public init() {}

    public func scan() async -> [ScanResult] {
        // This module doesn't produce file-based scan results.
        // It provides live system state. Returning empty for now —
        // the view model will query live data directly.
        []
    }
}

// MARK: - Login Items Manager

public final class LoginItemsManager: @unchecked Sendable {
    public struct LoginItem: Identifiable, Sendable {
        public let id: UUID = UUID()
        public let name: String
        public let path: URL
        public let bundleIdentifier: String?
        public var isEnabled: Bool
    }

    public init() {}

    public func getLoginItems() -> [LoginItem] {
        // Read launch agents from ~/Library/LaunchAgents
        let launchAgentsDir = MCConstants.userLaunchAgents
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: launchAgentsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var items: [LoginItem] = []
        for plistURL in contents where plistURL.pathExtension == "plist" {
            guard let data = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { continue }

            let label = plist["Label"] as? String ?? plistURL.deletingPathExtension().lastPathComponent
            let disabled = plist["Disabled"] as? Bool ?? false

            items.append(LoginItem(
                name: label,
                path: plistURL,
                bundleIdentifier: plist["Label"] as? String,
                isEnabled: !disabled
            ))
        }

        return items
    }

    public func toggleItem(_ item: LoginItem, enabled: Bool) throws {
        guard let data = try? Data(contentsOf: item.path),
              var plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return }

        plist["Disabled"] = !enabled
        let newData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try newData.write(to: item.path)
    }
}

// MARK: - Launch Agents Manager

public final class LaunchAgentsManager: @unchecked Sendable {
    public struct LaunchAgent: Identifiable, Sendable {
        public let id: UUID = UUID()
        public let label: String
        public let path: URL
        public let program: String?
        public let isSystem: Bool
        public var isEnabled: Bool
    }

    public init() {}

    public func getLaunchAgents() -> [LaunchAgent] {
        var agents: [LaunchAgent] = []

        agents.append(contentsOf: scanDirectory(MCConstants.userLaunchAgents, isSystem: false))
        agents.append(contentsOf: scanDirectory(MCConstants.systemLaunchAgents, isSystem: true))

        return agents
    }

    private func scanDirectory(_ dir: URL, isSystem: Bool) -> [LaunchAgent] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }

        var agents: [LaunchAgent] = []
        for plistURL in contents where plistURL.pathExtension == "plist" {
            guard let data = try? Data(contentsOf: plistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
            else { continue }

            let label = plist["Label"] as? String ?? plistURL.deletingPathExtension().lastPathComponent
            let program: String?
            if let prog = plist["Program"] as? String {
                program = prog
            } else if let args = plist["ProgramArguments"] as? [String] {
                program = args.first
            } else {
                program = nil
            }
            let disabled = plist["Disabled"] as? Bool ?? false

            agents.append(LaunchAgent(
                label: label,
                path: plistURL,
                program: program,
                isSystem: isSystem,
                isEnabled: !disabled
            ))
        }
        return agents
    }
}

// MARK: - Process Monitor

public final class ProcessMonitor: @unchecked Sendable {
    public struct ProcessInfo: Identifiable, Sendable {
        public let id: Int32
        public let name: String
        public let cpuUsage: Double
        public let memoryBytes: UInt64
        public let isResponsive: Bool
    }

    public init() {}

    public func getRunningApps() -> [ProcessInfo] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let name = app.localizedName, !app.isHidden else { return nil }
            return ProcessInfo(
                id: app.processIdentifier,
                name: name,
                cpuUsage: 0, // Would need host_processor_info for per-process CPU
                memoryBytes: 0,
                isResponsive: !app.isTerminated
            )
        }
    }

    public func forceQuit(pid: Int32) {
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.forceTerminate()
        }
    }
}
