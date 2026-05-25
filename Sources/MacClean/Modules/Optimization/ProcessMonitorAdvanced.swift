import Foundation
import AppKit
import Darwin

public actor ProcessStatsCollector {
    public struct ProcessStats: Identifiable, Sendable {
        public let id: Int32 // pid
        public let name: String
        public let cpuPercent: Double
        public let memoryBytes: UInt64
        public let isResponsive: Bool
        public let bundleIdentifier: String?
    }

    private var previousCPUTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]

    public init() {}

    public func getProcessStats() -> [ProcessStats] {
        let apps = NSWorkspace.shared.runningApplications
        var results: [ProcessStats] = []

        for app in apps {
            guard let name = app.localizedName else { continue }
            let pid = app.processIdentifier

            let cpu = cpuUsage(for: pid)
            let mem = memoryUsage(for: pid)

            results.append(ProcessStats(
                id: pid,
                name: name,
                cpuPercent: cpu,
                memoryBytes: mem,
                isResponsive: !app.isTerminated,
                bundleIdentifier: app.bundleIdentifier
            ))
        }

        return results.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    public func getHungApps() -> [ProcessStats] {
        getProcessStats().filter { !$0.isResponsive }
    }

    public func getHeavyConsumers(cpuThreshold: Double = 50.0) -> [ProcessStats] {
        getProcessStats().filter { $0.cpuPercent > cpuThreshold }
    }

    private func cpuUsage(for pid: Int32) -> Double {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size

        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
        guard result == size else { return 0 }

        let currentUser = taskInfo.pti_total_user
        let currentSystem = taskInfo.pti_total_system
        let now = Date()

        if let prev = previousCPUTimes[pid] {
            let elapsed = now.timeIntervalSince(prev.timestamp)
            guard elapsed > 0 else { return 0 }

            let userDiff = Double(currentUser - prev.user) / 1_000_000_000 // ns to s
            let sysDiff = Double(currentSystem - prev.system) / 1_000_000_000
            let cpuPercent = ((userDiff + sysDiff) / elapsed) * 100

            previousCPUTimes[pid] = (currentUser, currentSystem, now)
            return min(cpuPercent, 100.0 * Double(ProcessInfo.processInfo.activeProcessorCount))
        }

        previousCPUTimes[pid] = (currentUser, currentSystem, now)
        return 0
    }

    private nonisolated func memoryUsage(for pid: Int32) -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        var task: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &task)
        guard kr == KERN_SUCCESS else { return 0 }
        defer { mach_port_deallocate(mach_task_self_, task) }

        let result = withUnsafeMutablePointer(to: &taskInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(taskInfo.resident_size)
    }
}
