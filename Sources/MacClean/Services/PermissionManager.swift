import Foundation
import MacCleanKit
import AppKit

public final class PermissionManager: Sendable {
    public static let shared = PermissionManager()

    private init() {}

    public var hasFullDiskAccess: Bool {
        let testPaths = [
            MCConstants.mailData.path(percentEncoded: false),
            MCConstants.home.appending(path: "Library/Messages").path(percentEncoded: false),
            MCConstants.home.appending(path: "Library/Safari").path(percentEncoded: false),
        ]

        return testPaths.contains { FileManager.default.isReadableFile(atPath: $0) }
    }

    public func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    public func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
