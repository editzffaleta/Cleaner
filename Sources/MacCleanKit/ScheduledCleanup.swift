import Foundation

/// How often the automatic cleanup runs.
public enum CleanupFrequency: String, CaseIterable, Sendable, Identifiable {
    case daily, weekly, monthly
    public var id: String { rawValue }

    public var interval: TimeInterval {
        switch self {
        case .daily:   return 24 * 3600
        case .weekly:  return 7 * 24 * 3600
        case .monthly: return 30 * 24 * 3600
        }
    }

    public var label: String {
        switch self {
        case .daily:   return L10n.tr("每天", "Diariamente")
        case .weekly:  return L10n.tr("每周", "Semanalmente")
        case .monthly: return L10n.tr("每月", "Mensalmente")
        }
    }
}

/// Preferences and "is it due?" logic for scheduled cleanup. Stored in the
/// shared app-group defaults so the value survives relaunches; the actual clean
/// is performed by the main app (`ScheduledCleanupRunner`).
public enum ScheduledCleanup {
    public static let enabledKey = "scheduledCleanupEnabled"
    public static let frequencyKey = "scheduledCleanupFrequency"
    public static let lastRunKey = "scheduledCleanupLastRun"

    private static var defaults: UserDefaults { SharedAppState.defaults }

    public static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    public static var frequency: CleanupFrequency {
        get { CleanupFrequency(rawValue: defaults.string(forKey: frequencyKey) ?? "") ?? .weekly }
        set { defaults.set(newValue.rawValue, forKey: frequencyKey) }
    }

    public static var lastRun: Date? {
        let t = defaults.double(forKey: lastRunKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    public static func markRun(_ date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: lastRunKey)
    }

    /// True when scheduling is on and enough time has elapsed since the last run
    /// (or it has never run).
    public static var isDue: Bool {
        guard isEnabled else { return false }
        guard let last = lastRun else { return true }
        return Date().timeIntervalSince(last) >= frequency.interval
    }
}
