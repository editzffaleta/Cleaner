import SwiftUI
import MacCleanKit

/// The Home dashboard ("Início") — a system overview with protection status,
/// storage breakdown, live vitals, and quick entry points to the modules.
struct HomeDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var model = HomeDashboardModel()

    private var green: Color { Color(red: 0.204, green: 0.827, blue: 0.600) }
    private var amber: Color { Color(red: 0.961, green: 0.714, blue: 0.220) }
    private var red: Color { Color(red: 0.949, green: 0.333, blue: 0.373) }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                systemStateCard
                HStack(spacing: 16) {
                    storageCard
                    vitalsCard
                }
                HStack(spacing: 16) {
                    quickCard(icon: "trash", tint: green,
                              title: L10n.tr("清理", "Limpeza"),
                              subtitle: L10n.tr("缓存、日志和应用残留。", "Cache, logs e restos de aplicativos."),
                              value: model.recoverableBytes.map { FileSizeFormatter.format($0) } ?? "—",
                              valueLabel: L10n.tr("可回收", "recuperável"),
                              action: L10n.tr("查看", "Revisar"), target: .systemJunk)
                    quickCard(icon: "checkmark.shield", tint: red,
                              title: L10n.tr("防护", "Proteção"),
                              subtitle: L10n.tr("恶意软件、跟踪器和隐私。", "Malware, rastreadores e privacidade."),
                              value: "\(model.protection?.threatsFound ?? 0)",
                              valueLabel: L10n.tr("威胁", "ameaças"),
                              action: L10n.tr("检查", "Verificar"), target: .malwareRemoval)
                    quickCard(icon: "gauge.with.dots.needle.67percent", tint: amber,
                              title: L10n.tr("性能", "Desempenho"),
                              subtitle: L10n.tr("占用高的应用与维护任务。", "Apps pesados e tarefas de manutenção."),
                              value: "\(model.heavyAppsCount ?? 0)",
                              valueLabel: L10n.tr("重型应用", "apps pesados"),
                              action: L10n.tr("优化", "Otimizar"), target: .optimization)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    // MARK: System state

    private var systemStateCard: some View {
        let threats = model.protection?.threatsFound ?? 0
        let protected = threats == 0
        let statusColor = protected ? green : red
        return HStack(alignment: .top, spacing: 20) {
            protectionRing(color: statusColor, protected: protected)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("系统状态", "ESTADO DO SISTEMA"))
                    .font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(.secondary)
                Text(protected ? L10n.tr("你的 Mac 已受保护", "Seu Mac está protegido")
                               : L10n.tr("发现 \(threats) 个威胁", "\(threats) ameaça\(threats == 1 ? "" : "s") encontrada\(threats == 1 ? "" : "s")"))
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                Text(lastScanSubtitle)
                    .font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.65))
                Button { appState.selectedSidebarItem = .smartScan } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .bold))
                        Text(L10n.tr("运行智能扫描", "Executar Escaneamento Inteligente")).font(.system(size: 13.5, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 11)
                    .background(LinearGradient(colors: [Color(red: 0.16, green: 0.78, blue: 0.83), Color.brand],
                                               startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .shadow(color: Color.brand.opacity(0.45), radius: 8, y: 4)
                }.buttonStyle(.plain).padding(.top, 4)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 16) {
                stateStat(value: model.recoverableBytes.map { FileSizeFormatter.format($0) } ?? "—",
                          label: L10n.tr("可回收", "Recuperável"))
                stateStat(value: "\(threats)", label: L10n.tr("威胁", "Ameaças"))
                stateStat(value: model.updatableCount.map { "\($0)" } ?? "—",
                          label: L10n.tr("可更新应用", "Apps p/ atualizar"))
            }
        }
        .padding(20)
        .dashCard()
    }

    private func protectionRing(color: Color, protected: Bool) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: 8)
            Circle().trim(from: 0, to: protected ? 1 : 0.35)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 6)
            Image(systemName: protected ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 34, weight: .medium)).foregroundStyle(color)
        }
        .frame(width: 100, height: 100)
    }

    private func stateStat(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value).font(.system(size: 19, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
        }
    }

    private var lastScanSubtitle: String {
        guard let p = model.protection else { return L10n.tr("尚未扫描", "Ainda não escaneado") }
        let rel = CleanupHistoryView.relativeDate(p.lastScanDate)
        let junk = model.recoverableBytes.map { FileSizeFormatter.format($0) } ?? "—"
        return L10n.tr("上次扫描 \(rel) · 可回收 \(junk) 垃圾",
                       "Último escaneamento \(rel) · \(junk) de lixo recuperável")
    }

    // MARK: Storage

    private var storageCard: some View {
        let total = model.stats?.diskTotal ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.tr("存储", "Armazenamento"), systemImage: "internaldrive")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text(L10n.tr("共 \(FileSizeFormatter.format(total))", "\(FileSizeFormatter.format(total)) no total"))
                    .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
            }
            storageBar
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                ForEach(model.storage) { slice in
                    HStack(spacing: 6) {
                        Circle().fill(slice.color).frame(width: 8, height: 8)
                        Text(slice.label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.8))
                        Text(FileSizeFormatter.format(slice.bytes)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashCard()
    }

    private var storageBar: some View {
        GeometryReader { geo in
            let sum = max(model.storage.reduce(0) { $0 + $1.bytes }, 1)
            HStack(spacing: 1.5) {
                ForEach(model.storage) { slice in
                    slice.color
                        .frame(width: max(2, geo.size.width * CGFloat(Double(slice.bytes) / Double(sum))))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 12)
    }

    // MARK: Vitals

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.tr("系统健康", "Vitais do sistema"), systemImage: "waveform.path.ecg")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            vitalBar(label: "CPU", value: model.stats?.cpuUsage ?? 0, color: green)
            vitalBar(label: L10n.tr("内存", "Memória"), value: model.stats?.memoryPressure ?? 0, color: amber)
            vitalBar(label: L10n.tr("磁盘", "Disco"), value: diskUsedFraction, color: red)
            HStack(spacing: 6) {
                Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                Text(L10n.tr("运行时间 · \(uptimeText)", "Tempo ativo · \(uptimeText)"))
                    .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashCard()
    }

    private func vitalBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(Int((value * 100).rounded()))%").font(.system(size: 12.5, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 7)
        }
    }

    private var diskUsedFraction: Double {
        guard let s = model.stats, s.diskTotal > 0 else { return 0 }
        return Double(s.diskTotal - s.diskFree) / Double(s.diskTotal)
    }

    private var uptimeText: String {
        let secs = Int(model.stats?.uptime ?? 0)
        let h = secs / 3600, m = (secs % 3600) / 60
        if h > 24 { return L10n.tr("\(h/24)天 \(h%24)小时", "\(h/24)d \(h%24)h") }
        return L10n.tr("\(h)小时 \(m)分", "\(h)h \(m)m")
    }

    // MARK: Quick cards

    private func quickCard(icon: String, tint: Color, title: String, subtitle: String,
                           value: String, valueLabel: String, action: String, target: SidebarItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            HStack(alignment: .firstTextBaseline) {
                Text(value).font(.system(size: 21, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Text(valueLabel).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button { appState.selectedSidebarItem = target } label: {
                    HStack(spacing: 3) {
                        Text(action).font(.system(size: 12.5, weight: .bold))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }.foregroundStyle(Color.brand)
                }.buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .dashCard()
    }
}

private extension View {
    /// Dark translucent card used across the Home dashboard.
    func dashCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            }
    }
}
