import SwiftUI
import MacCleanKit

public enum SidebarItem: String, CaseIterable, Identifiable {
    // Main
    case smartScan = "智能扫描"

    // Cleanup
    case systemJunk = "系统垃圾"
    case mailAttachments = "邮件附件"
    case trashBins = "废纸篓"

    // Protection
    case malwareRemoval = "恶意软件清理"
    case privacy = "隐私清理"

    // Performance
    case optimization = "优化"
    case maintenance = "维护"

    // Applications
    case uninstaller = "卸载器"
    case updater = "应用更新"

    // Files
    case spaceLens = "空间透视"
    case largeOldFiles = "大文件与旧文件"
    case duplicates = "重复文件"
    case shredder = "文件粉碎"

    // Footer (pinned below the list, not rendered in any section)
    case settings = "设置"
    case cleanupHistory = "清理历史"

    public var id: String { rawValue }
    public var title: String { L10n.tr(rawValue) }

    /// Stable slug used in `macclean://module/<id>` deep links.
    public var deepLinkID: String {
        switch self {
        case .smartScan: "smart-scan"
        case .systemJunk: "system-junk"
        case .mailAttachments: "mail-attachments"
        case .trashBins: "trash-bins"
        case .malwareRemoval: "malware"
        case .privacy: "privacy"
        case .optimization: "optimization"
        case .maintenance: "maintenance"
        case .uninstaller: "uninstaller"
        case .updater: "updater"
        case .spaceLens: "space-lens"
        case .largeOldFiles: "large-old-files"
        case .duplicates: "duplicates"
        case .shredder: "shredder"
        case .settings: "settings"
        case .cleanupHistory: "cleanup-history"
        }
    }

    public init?(deepLinkID: String) {
        guard let match = Self.allCases.first(where: { $0.deepLinkID == deepLinkID }) else { return nil }
        self = match
    }

    public var icon: String {
        switch self {
        case .smartScan: "sparkle.magnifyingglass"
        case .systemJunk: "trash.circle"
        case .mailAttachments: "paperclip.circle"
        case .trashBins: "trash"
        case .malwareRemoval: "shield.lefthalf.filled"
        case .privacy: "hand.raised.fill"
        case .optimization: "gauge.with.dots.needle.67percent"
        case .maintenance: "wrench.and.screwdriver"
        case .uninstaller: "xmark.app"
        case .updater: "arrow.triangle.2.circlepath"
        case .spaceLens: "chart.pie"
        case .largeOldFiles: "doc.richtext"
        case .duplicates: "plus.square.on.square"
        case .shredder: "scissors"
        case .settings: "gearshape"
        case .cleanupHistory: "clock.arrow.circlepath"
        }
    }

    public var theme: ModuleTheme {
        switch self {
        case .smartScan: .smartScan
        case .systemJunk, .mailAttachments, .trashBins: .cleanup
        case .malwareRemoval, .privacy: .protection
        case .optimization, .maintenance: .performance
        case .uninstaller, .updater: .applications
        case .spaceLens, .largeOldFiles, .duplicates, .shredder: .files
        case .settings: .settings
        case .cleanupHistory: .settings
        }
    }

    public var section: SidebarSection {
        switch self {
        case .smartScan: .main
        case .systemJunk, .mailAttachments, .trashBins: .cleanup
        case .malwareRemoval, .privacy: .protection
        case .optimization, .maintenance: .performance
        case .uninstaller, .updater: .applications
        case .spaceLens, .largeOldFiles, .duplicates, .shredder: .files
        case .settings: .main
        case .cleanupHistory: .main
        }
    }
}

public enum SidebarSection: String, CaseIterable, Identifiable {
    case main = ""
    case cleanup = "清理"
    case protection = "防护"
    case performance = "性能"
    case applications = "应用"
    case files = "文件"

    public var id: String { rawValue }
    public var title: String { L10n.tr(rawValue) }

    public var items: [SidebarItem] {
        // .settings is pinned to the footer; it never renders inside a section.
        SidebarItem.allCases.filter { $0.section == self && $0 != .settings && $0 != .cleanupHistory }
    }
}

public struct SidebarView: View {
    @Binding var selection: SidebarItem?
    /// Sections the user has collapsed. We render our own collapsible headers
    /// with an always-visible chevron that folds on tap.
    @State private var collapsedSections: Set<SidebarSection> = []

    // Design tokens (from the Cleaner redesign).
    private static let sidebarTop = Color(red: 0.055, green: 0.11, blue: 0.15)
    private static let sidebarBottom = Color(red: 0.04, green: 0.062, blue: 0.09)
    private static let headerColor = Color(red: 0.37, green: 0.455, blue: 0.535)
    private static let itemColor = Color(red: 0.86, green: 0.89, blue: 0.925)
    private static let pillTop = Color(red: 0.16, green: 0.78, blue: 0.83)

    public init(selection: Binding<SidebarItem?>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Traffic-light gutter spacer so the first item clears the window
            // controls, matching the mockup.
            Color.clear.frame(height: 40)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(SidebarSection.allCases) { section in
                        if section == .main {
                            ForEach(section.items) { sidebarRow($0) }
                        } else {
                            sectionHeader(section)
                            if !collapsedSections.contains(section) {
                                ForEach(section.items) { sidebarRow($0) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            Divider().overlay(Color.white.opacity(0.06))

            footerRow(item: .cleanupHistory, icon: "clock.arrow.circlepath",
                      title: L10n.tr("清理历史", "Histórico de Limpezas"), trailing: nil)
            footerRow(item: .settings, icon: "gearshape",
                      title: L10n.tr("设置", "Ajustes"), trailing: "v\(MCConstants.appVersion)")
                .padding(.bottom, 8)
        }
        .frame(minWidth: 210, idealWidth: 240)
        .background(
            LinearGradient(colors: [Self.sidebarTop, Self.sidebarBottom],
                           startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .top) {
                    LinearGradient(colors: [Color.brand.opacity(0.10), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 220)
                }
                .ignoresSafeArea()
        )
    }

    /// Collapsible section header: chevron + uppercased title; taps fold it.
    private func sectionHeader(_ section: SidebarSection) -> some View {
        let isCollapsed = collapsedSections.contains(section)
        return HStack(spacing: 6) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 9, weight: .bold))
            Text(section.title.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.1)
            Spacer()
        }
        .foregroundStyle(Self.headerColor)
        .padding(.horizontal, 13)
        .padding(.top, 14).padding(.bottom, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.18)) {
                if isCollapsed { collapsedSections.remove(section) }
                else { collapsedSections.insert(section) }
            }
        }
    }

    /// A sidebar item as a rounded pill; the selected one gets an accent
    /// gradient fill with a soft glow.
    private func sidebarRow(_ item: SidebarItem) -> some View {
        let selected = selection == item
        return HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : item.theme.accentColor)
                .frame(width: 18)
            Text(item.title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(selected ? .white : Self.itemColor)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(rowBackground(selected: selected))
        .contentShape(Rectangle())
        .onTapGesture { selection = item }
    }

    private func footerRow(item: SidebarItem, icon: String, title: String, trailing: String?) -> some View {
        let selected = selection == item
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? .white : Self.itemColor.opacity(0.9))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : Self.itemColor)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(selected ? .white.opacity(0.8) : Self.headerColor)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(rowBackground(selected: selected))
        .contentShape(Rectangle())
        .onTapGesture { selection = item }
        .padding(.horizontal, 12).padding(.top, 6)
    }

    @ViewBuilder
    private func rowBackground(selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Self.pillTop, Color.brand],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.brand.opacity(0.45), radius: 7, y: 4)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                }
        } else {
            Color.clear
        }
    }
}
