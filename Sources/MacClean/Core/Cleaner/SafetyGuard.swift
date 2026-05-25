import Foundation
import MacCleanKit

public struct SafetyGuard: Sendable {
    public enum SafetyError: Error, LocalizedError {
        case protectedPath(String)
        case tooManyFiles(Int)
        case symlinkTarget(String)
        case sipProtected(String)
        case outsideUserScope(String)

        public var errorDescription: String? {
            switch self {
            case .protectedPath(let path):
                "Cannot modify protected system path: \(path)"
            case .tooManyFiles(let count):
                "Operation exceeds safety limit of \(MCConstants.maxFilesPerOperation) files (attempted: \(count))"
            case .symlinkTarget(let path):
                "Path resolves through symlink to unexpected location: \(path)"
            case .sipProtected(let path):
                "Path is protected by System Integrity Protection: \(path)"
            case .outsideUserScope(let path):
                "Path is outside the allowed user scope: \(path)"
            }
        }
    }

    public init() {}

    public func validateDeletion(paths: [URL]) throws {
        if paths.count > MCConstants.maxFilesPerOperation {
            throw SafetyError.tooManyFiles(paths.count)
        }

        for path in paths {
            try validatePath(path)
        }
    }

    public func validatePath(_ url: URL) throws {
        let resolvedPath = url.resolvingSymlinksInPath().path(percentEncoded: false)

        for protected in MCConstants.protectedPaths {
            if resolvedPath.hasPrefix(protected + "/") || resolvedPath == protected {
                throw SafetyError.protectedPath(resolvedPath)
            }
        }

        if resolvedPath.hasPrefix("/System/") {
            throw SafetyError.sipProtected(resolvedPath)
        }

        let originalPath = url.path(percentEncoded: false)
        if originalPath != resolvedPath {
            let originalComponents = originalPath.components(separatedBy: "/")
            let resolvedComponents = resolvedPath.components(separatedBy: "/")
            if originalComponents.prefix(3) != resolvedComponents.prefix(3) {
                throw SafetyError.symlinkTarget(resolvedPath)
            }
        }
    }

    public func isProtectedApp(_ bundleID: String) -> Bool {
        MCConstants.protectedApps.contains(bundleID)
    }

    public func isSafeForOrphanDeletion(_ url: URL) -> Bool {
        let path = url.path(percentEncoded: false)
        let safePrefixes = [
            MCConstants.userCaches.path(percentEncoded: false),
            MCConstants.userLogs.path(percentEncoded: false),
            MCConstants.userHTTPStorages.path(percentEncoded: false),
            MCConstants.userSavedAppState.path(percentEncoded: false),
            MCConstants.userWebKit.path(percentEncoded: false),
        ]
        return safePrefixes.contains { path.hasPrefix($0) }
    }
}
