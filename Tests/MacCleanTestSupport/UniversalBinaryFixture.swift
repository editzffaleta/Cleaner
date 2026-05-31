import Foundation
import XCTest

/// Builds real universal Mach-O binaries on disk for tests that exercise the
/// production lipo + codesign code path. Uses the system `cc` to compile a
/// trivial C source with multiple `-arch` flags.
public enum UniversalBinaryFixture {

    /// Compiles a universal binary from a hello-world C source into `outputURL`.
    /// Returns false if `cc` isn't on PATH (rare on macOS) — caller should
    /// `XCTSkip` in that case.
    @discardableResult
    public static func build(
        at outputURL: URL,
        architectures: [String] = ["x86_64", "arm64"]
    ) throws -> Bool {
        guard FileManager.default.fileExists(atPath: "/usr/bin/cc") else {
            return false
        }
        let dir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let src = dir.appending(path: "hello-\(UUID().uuidString).c")
        // Embed ~256KB of constant data per slice so the binary is big enough
        // that thinning's savings dominate any per-file overhead like
        // ad-hoc codesign metadata. Without this, a tiny hello-world ends up
        // ~50KB thin where the +signature overhead is the same order of
        // magnitude as the strip savings — fine in production, useless in tests.
        let code = """
        #include <stdio.h>
        static const char filler[262144] = {
        #ifdef __aarch64__
            0xA,
        #else
            0xB,
        #endif
        };
        // Read the filler so the linker keeps it (otherwise -dead_strip
        // would discard the unused static and the binary shrinks back to
        // hello-world size).
        int main(void) {
            volatile char keep = filler[0];
            (void)keep;
        #ifdef __aarch64__
            printf("arm64\\n");
        #else
            printf("x86_64\\n");
        #endif
            return 0;
        }
        """
        try code.write(to: src, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: src) }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/cc")
        var args: [String] = []
        for arch in architectures {
            args.append("-arch")
            args.append(arch)
        }
        args.append("-o")
        args.append(outputURL.path(percentEncoded: false))
        args.append(src.path(percentEncoded: false))
        process.arguments = args
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Reads architectures via lipo. Returns `[]` if lipo fails (e.g. file is
    /// not Mach-O), or the single-arch array for a non-fat file.
    public static func architectures(of binary: URL) -> [String] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/lipo")
        process.arguments = ["-info", binary.path(percentEncoded: false)]
        process.standardOutput = pipe
        process.standardError = Pipe()

        guard (try? process.run()) != nil else { return [] }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }

        let output = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        if let range = output.range(of: "are: ") {
            return output[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .map(String.init)
        }
        if let range = output.range(of: "is architecture: ") {
            let arch = output[range.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [arch]
        }
        return []
    }

    /// True if codesign verifies the binary (exit 0).
    public static func codesignVerifies(_ binary: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/codesign")
        process.arguments = ["-v", binary.path(percentEncoded: false)]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
