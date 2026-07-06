import SwiftUI
import MacCleanKit

/// Timeline of past clean operations: how much space was freed, when, and by
/// which module. Backed by `CleanHistoryStore` (a JSON log).
struct CleanupHistoryView: View {
    @State private var entries: [CleanHistoryEntry] = []
    @State private var showClearConfirm = false

    private var totalFreed: UInt64 { entries.reduce(0) { $0 + $1.freedBytes } }
    private var totalRemoved: Int { entries.reduce(0) { $0 + $1.removedCount } }

    var body: some View {
        VStack(spacing: 0) {
            header
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        summaryCard
                        if dailyBuckets.contains(where: { $0.bytes > 0 }) {
                            chartCard
                        }
                        historyList
                    }
                    .padding(20)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { entries = CleanHistoryStore.all() }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("清理历史", "Histórico de Limpezas"))
                    .font(.system(size: 22, weight: .bold))
                Text(L10n.tr("查看你已释放的空间", "Veja quanto espaço você já liberou"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if !entries.isEmpty {
                Button(role: .destructive) { showClearConfirm = true } label: {
                    Label(L10n.tr("清空历史", "Limpar histórico"), systemImage: "trash")
                }
                .controlSize(.small)
                .confirmationDialog(L10n.tr("清空清理历史？", "Limpar o histórico de limpezas?"),
                                    isPresented: $showClearConfirm, titleVisibility: .visible) {
                    Button(L10n.tr("清空", "Limpar"), role: .destructive) {
                        CleanHistoryStore.clear(); entries = []
                    }
                    Button(L10n.tr("取消", "Cancelar"), role: .cancel) {}
                }
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    // MARK: Summary

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryStat(value: FileSizeFormatter.format(totalFreed),
                        label: L10n.tr("总共释放", "Total liberado"), tint: Color.brand)
            Divider().frame(height: 40)
            summaryStat(value: totalRemoved.formatted(),
                        label: L10n.tr("已移除项目", "Itens removidos"), tint: MenuAccent.green)
            Divider().frame(height: 40)
            summaryStat(value: entries.count.formatted(),
                        label: L10n.tr("清理次数", "Limpezas"), tint: MenuAccent.amber)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryStat(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Chart (last 14 days)

    private var chartCard: some View {
        let buckets = dailyBuckets
        let maxBytes = max(buckets.map(\.bytes).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("最近 14 天", "Últimos 14 dias"))
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(buckets) { bucket in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(bucket.bytes > 0 ? Color.brand : Color.secondary.opacity(0.15))
                            .frame(height: max(3, CGFloat(Double(bucket.bytes) / Double(maxBytes)) * 90))
                        Text(bucket.dayLabel)
                            .font(.system(size: 8)).foregroundStyle(.tertiary)
                            .lineLimit(1).fixedSize()
                    }
                    .frame(maxWidth: .infinity)
                    .help(bucket.bytes > 0 ? FileSizeFormatter.format(bucket.bytes) : "")
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: List

    private var historyList: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    Image(systemName: Self.sourceIcon(entry.source))
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brand)
                        .frame(width: 30, height: 30)
                        .background(Color.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.sourceLabel(entry.source)).font(.system(size: 13, weight: .semibold))
                        Text(Self.relativeDate(entry.date)).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FileSizeFormatter.format(entry.freedBytes))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.brand)
                        Text(L10n.tr("\(entry.removedCount) 项", "\(entry.removedCount) itens"))
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    if entry.id != entries.last?.id { Divider().padding(.leading, 56) }
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 46)).foregroundStyle(.secondary.opacity(0.5))
            Text(L10n.tr("暂无清理记录", "Nenhuma limpeza registrada ainda"))
                .font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            Text(L10n.tr("完成一次清理后，这里会显示你释放的空间。", "Depois de fazer uma limpeza, o espaço liberado aparece aqui."))
                .font(.system(size: 12)).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Aggregation

    private struct DayBucket: Identifiable {
        let id: Int
        let bytes: UInt64
        let dayLabel: String
    }

    private var dailyBuckets: [DayBucket] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter(); fmt.dateFormat = "d/M"
        return (0..<14).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let next = cal.date(byAdding: .day, value: 1, to: day) ?? day
            let bytes = entries
                .filter { $0.date >= day && $0.date < next }
                .reduce(0 as UInt64) { $0 + $1.freedBytes }
            return DayBucket(id: offset, bytes: bytes, dayLabel: fmt.string(from: day))
        }
    }

    // MARK: Labels

    static func sourceLabel(_ source: String) -> String {
        switch source {
        case CleanHistorySource.smartScan: return L10n.tr("智能扫描", "Escaneamento Inteligente")
        case CleanHistorySource.systemJunk: return L10n.tr("系统垃圾", "Lixo do Sistema")
        case CleanHistorySource.duplicates: return L10n.tr("重复文件", "Duplicatas")
        case CleanHistorySource.uninstaller: return L10n.tr("卸载器", "Desinstalador")
        case CleanHistorySource.scheduled: return L10n.tr("定时清理", "Limpeza agendada")
        case CleanHistorySource.widget: return L10n.tr("菜单栏", "Widget")
        default: return L10n.tr("手动清理", "Limpeza manual")
        }
    }

    static func sourceIcon(_ source: String) -> String {
        switch source {
        case CleanHistorySource.smartScan: return "sparkle.magnifyingglass"
        case CleanHistorySource.systemJunk: return "trash.circle"
        case CleanHistorySource.duplicates: return "plus.square.on.square"
        case CleanHistorySource.uninstaller: return "xmark.app"
        case CleanHistorySource.scheduled: return "clock.badge.checkmark"
        case CleanHistorySource.widget: return "menubar.rectangle"
        default: return "hand.tap"
        }
    }

    static func relativeDate(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .full
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

/// A couple of accent colors reused from the widget palette for the summary.
enum MenuAccent {
    static let green = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let amber = Color(red: 0.961, green: 0.714, blue: 0.220)
}
