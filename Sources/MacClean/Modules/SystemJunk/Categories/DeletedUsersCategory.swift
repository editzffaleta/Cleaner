import Foundation
import MacCleanKit

struct DeletedUsersCategory: JunkCategory {
    let scanCategory = ScanCategory.deletedUsers

    var targets: [ScanTarget] { [] }

    func scanForDeletedUserFolders() -> [FileItem] {
        let fm = FileManager.default
        let usersDir = URL(filePath: "/Users")

        guard let userFolders = try? fm.contentsOfDirectory(
            at: usersDir,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey]
        ) else { return [] }

        let activeUsers = getActiveUsernames()

        var results: [FileItem] = []

        for folder in userFolders {
            let values = try? folder.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }

            let name = folder.lastPathComponent

            // Skip system folders
            if ["Shared", ".localized", "Guest"].contains(name) { continue }
            if name.hasPrefix(".") { continue }

            // If this folder doesn't match an active user account, it's a residual
            if !activeUsers.contains(name) {
                let size = directorySize(folder)
                results.append(FileItem(
                    url: folder,
                    name: name,
                    size: size,
                    allocatedSize: size,
                    isDirectory: true
                ))
            }
        }

        return results
    }

    private func getActiveUsernames() -> Set<String> {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/dscl")
        process.arguments = [".", "-list", "/Users"]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let users = output.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("_") }
            return Set(users)
        } catch {
            return Set()
        }
    }

    private func directorySize(_ url: URL) -> UInt64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            let v = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
            total += UInt64(v?.totalFileAllocatedSize ?? 0)
        }
        return total
    }
}
