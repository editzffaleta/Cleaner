import Foundation

/// Volume usage summary from `URLResourceValues` or `statfs`.
public struct DiskUsage: Sendable, Equatable {
    public let total: UInt64
    public let free: UInt64

    public init(total: UInt64, free: UInt64) {
        self.total = total
        self.free = min(free, total) // sanity: free can never exceed total
    }

    public var used: UInt64 { total >= free ? total - free : 0 }

    /// Fraction of the volume that's in use (0…1).
    public var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }
}
