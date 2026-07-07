import SwiftUI
import MacCleanKit

public enum SidebarItem: String, CaseIterable, Identifiable {
    // Main
    case home = "首页"
    case smartScan = "智能扫描"

    // Cleanup
    case systemJunk = "系统垃圾"
    case systemData = "系统数据"
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
        case .home: "home"
        case .smartScan: "smart-scan"
        case .systemJunk: "system-junk"
        case .systemData: "system-data"
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
        case .home: "house"
        case .smartScan: "magnifyingglass"
        case .systemJunk: "trash.circle"
        case .systemData: "macpro.gen3"
        case .mailAttachments: "paperclip"
        case .trashBins: "trash"
        case .malwareRemoval: "shield.lefthalf.filled"
        case .privacy: "eye.slash"
        case .optimization: "gauge.with.needle"
        case .maintenance: "wrench.and.screwdriver.fill"
        case .uninstaller: "xmark.square"
        case .updater: "arrow.triangle.2.circlepath"
        case .spaceLens: "clock.badge.questionmark"
        case .largeOldFiles: "doc.text.magnifyingglass"
        case .duplicates: "plus.square.on.square"
        case .shredder: "scissors"
        case .settings: "gearshape"
        case .cleanupHistory: "clock.arrow.circlepath"
        }
    }

    public var theme: ModuleTheme {
        switch self {
        case .home: .smartScan
        case .smartScan: .smartScan
        case .systemJunk, .systemData, .mailAttachments, .trashBins: .cleanup
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
        case .home: .main
        case .smartScan: .main
        case .systemJunk, .systemData, .mailAttachments, .trashBins: .cleanup
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
    @State private var collapsedSections: Set<SidebarSection> = []

    public init(selection: Binding<SidebarItem?>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    Color.clear.frame(height: 38)   // espaço dos botões de janela

                    dsRow(.home)
                    dsRow(.smartScan)
                        .padding(.bottom, 10)

                    ForEach(SidebarSection.allCases.filter { $0 != .main }) { section in
                        sectionHeader(section)
                        if !collapsedSections.contains(section) {
                            ForEach(section.items) { dsRow($0) }
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            footerButton(item: .settings, icon: "gearshape",
                         title: L10n.tr("设置", "Ajustes"), trailing: "v\(MCConstants.appVersion)")
                .padding(12)
        }
        .frame(width: 250)
        .background(Theme.sidebar.ignoresSafeArea())
    }

    /// Cabeçalho de seção: chevron 8pt bold + título 10 bold kerning 1.0,
    /// accent 55%, dobra com spring 0.2 (DESIGN_SYSTEM §8.1).
    private func sectionHeader(_ section: SidebarSection) -> some View {
        let isCollapsed = collapsedSections.contains(section)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isCollapsed { collapsedSections.remove(section) }
                else { collapsedSections.insert(section) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                Text(section.title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.0)
                Spacer()
            }
            .foregroundStyle(Theme.accent.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Item da sidebar: pill accent com texto/ícone pretos quando selecionado,
    /// hover branco 6% (DESIGN_SYSTEM §8.1).
    private func dsRow(_ item: SidebarItem) -> some View {
        DSSidebarRow(item: item, selection: $selection)
    }

    private func footerButton(item: SidebarItem, icon: String, title: String, trailing: String?) -> some View {
        let isSelected = selection == item
        return Button { selection = item } label: {
            HStack {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .foregroundStyle(isSelected ? Color.black.opacity(0.8) : .white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? item.dsAccent : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Linha da sidebar com hover próprio (estado local).
private struct DSSidebarRow: View {
    let item: SidebarItem
    @Binding var selection: SidebarItem?
    @State private var hovering = false

    private var isSelected: Bool { selection == item }

    var body: some View {
        Button { selection = item } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.75) : item.dsIconColor)
                    .frame(width: 18)
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.85) : .white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? item.dsAccent : hovering ? Color.white.opacity(0.06) : .clear)
                    .shadow(color: isSelected ? item.dsAccent.opacity(0.5) : .clear, radius: 10, y: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
