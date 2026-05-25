import Foundation
import MacCleanKit

struct UniversalBinariesCategory: JunkCategory {
    let scanCategory = ScanCategory.universalBinaries

    var targets: [ScanTarget] { [] }

    func scanForRedundantSlices() -> [FileItem] {
        var results: [FileItem] = []
        let fm = FileManager.default
        let appsDir = URL(filePath: "/Applications")

        guard let apps = try? fm.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil)
        else { return [] }

        #if arch(arm64)
        let redundantArch = "x86_64"
        #else
        let redundantArch = "arm64"
        #endif

        for appURL in apps where appURL.pathExtension == "app" {
            let macOSDir = appURL.appending(path: "Contents/MacOS")
            guard let binaries = try? fm.contentsOfDirectory(at: macOSDir, includingPropertiesForKeys: nil)
            else { continue }

            for binaryURL in binaries {
                guard let archInfo = getArchitectures(binaryURL) else { continue }

                if archInfo.contains(redundantArch) && archInfo.count > 1 {
                    let values = try? binaryURL.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
                    let size = UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
                    let estimatedSaving = size / UInt64(archInfo.count)

                    results.append(FileItem(
                        url: binaryURL,
                        name: "\(appURL.deletingPathExtension().lastPathComponent) (\(redundantArch) slice)",
                        size: estimatedSaving,
                        allocatedSize: estimatedSaving,
                        isDirectory: false
                    ))
                }
            }
        }

        return results
    }

    private func getArchitectures(_ url: URL) -> [String]? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/lipo")
        process.arguments = ["-info", url.path(percentEncoded: false)]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Output format: "Architectures in the fat file: ... are: x86_64 arm64"
            // Or: "Non-fat file: ... is architecture: arm64"
            if output.contains("are:") {
                let parts = output.components(separatedBy: "are:").last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: " ") ?? []
                return parts.isEmpty ? nil : parts
            } else if output.contains("is architecture:") {
                let arch = output.components(separatedBy: "is architecture:").last?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return arch.map { [$0] }
            }
        } catch {}

        return nil
    }
}
