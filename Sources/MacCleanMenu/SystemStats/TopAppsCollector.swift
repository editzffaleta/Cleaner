import AppKit
import Darwin

/// One running app with its live memory footprint, for the "Connected" list in
/// the menu-bar widget. Holds an `NSImage` icon, so it stays `@MainActor` and is
/// never sent across an actor boundary (collected and rendered on the main actor).
@MainActor
struct RunningAppInfo: Identifiable {
    let id: Int32          // pid
    let name: String
    let memory: UInt64     // phys_footprint bytes (matches Activity Monitor)
    let icon: NSImage?
}

/// Collects the top foreground apps by memory footprint. Uses
/// `proc_pid_rusage` (a cheap syscall) per visible app — no shelling out.
@MainActor
enum TopAppsCollector {
    static func collect(limit: Int = 6) -> [RunningAppInfo] {
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        var infos: [RunningAppInfo] = []
        for app in apps {
            let pid = app.processIdentifier
            guard pid > 0, let mem = physFootprint(pid: pid), mem > 0 else { continue }
            infos.append(RunningAppInfo(
                id: pid,
                name: app.localizedName ?? "—",
                memory: mem,
                icon: app.icon
            ))
        }
        return Array(infos.sorted { $0.memory > $1.memory }.prefix(limit))
    }

    /// Physical memory footprint of a process, or nil if it can't be read
    /// (e.g. owned by another user). Mirrors Activity Monitor's "Memory".
    private static func physFootprint(pid: Int32) -> UInt64? {
        var info = rusage_info_current()
        let rc = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard rc == 0 else { return nil }
        return info.ri_phys_footprint
    }
}
