import Foundation
import IOKit
import IOKit.ps

public actor SystemStatsCollector {
    public struct SystemStats: Sendable {
        public let cpuUsage: Double
        public let cpuTemperature: Double?
        public let memoryTotal: UInt64
        public let memoryUsed: UInt64
        public let memoryPressure: Double
        public let swapUsed: UInt64
        public let diskTotal: UInt64
        public let diskFree: UInt64
        public let batteryLevel: Double?
        public let batteryHealth: Double?
        public let batteryIsCharging: Bool
        public let batteryCycleCount: Int?
        public let batteryTemperature: Double?
        public let uptime: TimeInterval
    }

    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) = (0, 0, 0, 0)

    public init() {}

    public func collect() -> SystemStats {
        let cpu = getCPUUsage()
        let memory = getMemoryInfo()
        let disk = getDiskInfo()
        let battery = getBatteryInfo()

        return SystemStats(
            cpuUsage: cpu,
            cpuTemperature: nil, // Requires SMC access
            memoryTotal: memory.total,
            memoryUsed: memory.used,
            memoryPressure: memory.pressure,
            swapUsed: memory.swapUsed,
            diskTotal: disk.total,
            diskFree: disk.free,
            batteryLevel: battery.level,
            batteryHealth: battery.health,
            batteryIsCharging: battery.isCharging,
            batteryCycleCount: battery.cycleCount,
            batteryTemperature: battery.temperature,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    // MARK: - CPU

    private func getCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<Int32>.size))
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(info[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[offset + Int(CPU_STATE_NICE)])
        }

        let userDiff = totalUser - previousCPUTicks.user
        let systemDiff = totalSystem - previousCPUTicks.system
        let idleDiff = totalIdle - previousCPUTicks.idle
        let niceDiff = totalNice - previousCPUTicks.nice

        previousCPUTicks = (totalUser, totalSystem, totalIdle, totalNice)

        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
        guard totalDiff > 0 else { return 0 }

        return Double(userDiff + systemDiff + niceDiff) / Double(totalDiff)
    }

    // MARK: - Memory

    private struct MemoryInfo {
        let total: UInt64
        let used: UInt64
        let pressure: Double
        let swapUsed: UInt64
    }

    private func getMemoryInfo() -> MemoryInfo {
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryInfo(total: total, used: 0, pressure: 0, swapUsed: 0)
        }

        let pageSize = UInt64(getpagesize())
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        let free = UInt64(stats.free_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let pressure = Double(used) / Double(total)

        // Swap info
        var swapStats = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapStats, &swapSize, nil, 0)
        let swapUsed = UInt64(swapStats.xsu_used)

        _ = (free, inactive) // Suppress unused warnings

        return MemoryInfo(total: total, used: used, pressure: pressure, swapUsed: swapUsed)
    }

    // MARK: - Disk

    private struct DiskInfo {
        let total: UInt64
        let free: UInt64
    }

    private func getDiskInfo() -> DiskInfo {
        let url = URL(filePath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ]) else {
            return DiskInfo(total: 0, free: 0)
        }

        return DiskInfo(
            total: UInt64(values.volumeTotalCapacity ?? 0),
            free: UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        )
    }

    // MARK: - Battery

    private struct BatteryInfo {
        let level: Double?
        let health: Double?
        let isCharging: Bool
        let cycleCount: Int?
        let temperature: Double?
    }

    private func getBatteryInfo() -> BatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatteryInfo(level: nil, health: nil, isCharging: false, cycleCount: nil, temperature: nil)
        }

        let currentCapacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

        let level = maxCapacity > 0 ? Double(currentCapacity) / Double(maxCapacity) : nil

        // Design capacity and cycle count require IOKit SMC access
        // For now, use the basic power source info
        return BatteryInfo(
            level: level,
            health: nil,
            isCharging: isCharging,
            cycleCount: nil,
            temperature: nil
        )
    }
}
