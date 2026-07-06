import SwiftUI
import MacCleanKit

// Cores semânticas fixas (DESIGN_SYSTEM §2).
private let green = Color(red: 0.45, green: 0.85, blue: 0.60)
private let yellow = Color(red: 0.95, green: 0.78, blue: 0.35)
private let red = Color(red: 0.95, green: 0.45, blue: 0.45)

/// Tela Início — dashboard do protótipo (HomeScreen) ligado aos dados reais
/// (HomeDashboardModel): vitais ao vivo, proteção, armazenamento e atalhos.
struct HomeDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var model = HomeDashboardModel()
    @State private var loaded = false

    private var threats: Int { model.protection?.threatsFound ?? 0 }
    private var protected: Bool { threats == 0 }
    private var statusColor: Color { protected ? green : red }
    private var recoverableText: String {
        model.recoverableBytes.map { FileSizeFormatter.format($0) } ?? "—"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                heroCard.reveal(delay: 0.05)

                HStack(alignment: .top, spacing: 16) {
                    storageCard.frame(maxWidth: .infinity).frame(height: 212)
                        .tilt3D(maxAngle: 3).reveal(delay: 0.15)
                    vitalsCard.frame(width: 330).frame(height: 212)
                        .tilt3D(maxAngle: 4).reveal(delay: 0.22)
                }

                HStack(spacing: 16) {
                    ActionCard(icon: "trash", color: green,
                               title: L10n.tr("清理", "Limpeza"),
                               subtitle: L10n.tr("缓存、日志和应用残留。", "Cache, logs e restos de aplicativos."),
                               value: recoverableText,
                               valueSuffix: L10n.tr("可回收", "recuperável"),
                               linkTitle: L10n.tr("查看", "Revisar")) { appState.selectedSidebarItem = .systemJunk }
                        .reveal(delay: 0.30)
                    ActionCard(icon: "checkmark.shield", color: red,
                               title: L10n.tr("防护", "Proteção"),
                               subtitle: L10n.tr("恶意软件、跟踪器和隐私。", "Malware, rastreadores e privacidade."),
                               value: "\(threats)",
                               valueSuffix: L10n.tr("威胁", "ameaças"),
                               valueColor: protected ? green : red,
                               linkTitle: L10n.tr("检查", "Verificar")) { appState.selectedSidebarItem = .malwareRemoval }
                        .reveal(delay: 0.38)
                    ActionCard(icon: "gauge.with.needle", color: yellow,
                               title: L10n.tr("性能", "Desempenho"),
                               subtitle: L10n.tr("占用高的应用与维护任务。", "Apps pesados e tarefas de manutenção."),
                               value: "\(model.heavyAppsCount ?? 0)",
                               valueSuffix: L10n.tr("重型应用", "apps pesados"),
                               linkTitle: L10n.tr("优化", "Otimizar")) { appState.selectedSidebarItem = .optimization }
                        .reveal(delay: 0.46)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 42)
            .padding(.bottom, 28)
            .frame(maxWidth: 1060)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            model.start()
            withAnimation(.spring(duration: 1.4).delay(0.3)) { loaded = true }
        }
        .onDisappear { model.stop() }
    }

    // MARK: Card principal

    private var heroCard: some View {
        HStack(spacing: 26) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.16))
                    .blur(radius: 18)
                    .pulseGlow(statusColor.opacity(0.4))

                Circle().stroke(.white.opacity(0.07), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: loaded ? (protected ? 0.85 : 0.35) : 0)
                    .stroke(
                        AngularGradient(colors: [statusColor.opacity(0.4), statusColor],
                                        center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(306)),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: statusColor.opacity(0.7), radius: 8)

                Circle().fill(statusColor.opacity(0.10)).padding(14)

                Image(systemName: protected ? "checkmark.shield" : "exclamationmark.shield")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.bounce, value: loaded)
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("系统状态", "ESTADO DO SISTEMA"))
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.4)
                    .foregroundStyle(Theme.accent.opacity(0.7))

                Text(protected ? L10n.tr("你的 Mac 已受保护", "Seu Mac está protegido")
                               : L10n.tr("发现 \(threats) 个威胁", "\(threats) ameaça\(threats == 1 ? "" : "s") encontrada\(threats == 1 ? "" : "s")"))
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.75)],
                                       startPoint: .top, endPoint: .bottom))

                Text(heroSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                GlowButton(title: L10n.tr("运行智能扫描", "Executar Escaneamento Inteligente"),
                           icon: "magnifyingglass") { appState.selectedSidebarItem = .smartScan }
                    .padding(.top, 8)
            }

            Spacer(minLength: 12)

            Rectangle()
                .fill(LinearGradient(colors: [.clear, .white.opacity(0.12), .clear],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 16) {
                heroStat(recoverableText, L10n.tr("可回收", "Recuperável"), .white)
                heroStat("\(threats)", L10n.tr("威胁", "Ameaças"), statusColor)
                heroStat(model.updatableCount.map { "\($0)" } ?? "—",
                         L10n.tr("可更新应用", "Apps p/ atualizar"), .white)
            }
            .frame(width: 132, alignment: .leading)
        }
        .padding(26)
        .glassCard(hoverLift: false)
        .overlay(LightSweep(cornerRadius: 18, period: 5.5))
    }

    private var heroSubtitle: String {
        guard let p = model.protection else {
            return L10n.tr("尚未扫描 · 可回收 \(recoverableText)", "Ainda não escaneado · \(recoverableText) de lixo recuperável")
        }
        let rel = CleanupHistoryView.relativeDate(p.lastScanDate)
        return L10n.tr("上次扫描 \(rel) · 可回收 \(recoverableText)",
                       "Último escaneamento \(rel) · \(recoverableText) de lixo recuperável")
    }

    private func heroStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: Armazenamento (dados reais do model)

    private var storageCard: some View {
        let totalBytes = model.stats?.diskTotal ?? 0
        let sumBytes = max(model.storage.reduce(0) { $0 + $1.bytes }, 1)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(L10n.tr("存储", "Armazenamento"), systemImage: "internaldrive")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(L10n.tr("共 \(FileSizeFormatter.format(totalBytes))", "\(FileSizeFormatter.format(totalBytes)) no total"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 12)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(model.storage) { s in
                        Rectangle()
                            .fill(
                                LinearGradient(colors: [s.color, s.color.opacity(0.7)],
                                               startPoint: .top, endPoint: .bottom))
                            .frame(width: loaded ? max(6, geo.size.width * CGFloat(Double(s.bytes) / Double(sumBytes))) : 6)
                            .shadow(color: s.color.opacity(0.5), radius: 5, y: 1)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 12)

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(model.storage) { s in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(s.color)
                                .frame(width: 7, height: 7)
                                .shadow(color: s.color.opacity(0.8), radius: 3)
                            (Text(s.label + "  ").font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                             + Text(FileSizeFormatter.format(s.bytes)).font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5)))
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: Vitais (dados reais)

    private var vitalsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.tr("系统健康", "Vitais do sistema"), systemImage: "waveform.path.ecg")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            vitalRow("CPU", model.stats?.cpuUsage ?? 0, green)
            vitalRow(L10n.tr("内存", "Memória"), model.stats?.memoryPressure ?? 0, yellow)
            vitalRow(L10n.tr("磁盘", "Disco"), diskUsedFraction, red)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(L10n.tr("运行时间 · \(uptimeText)", "Tempo ativo · \(uptimeText)"))
            }
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 2)
        }
        .padding(20)
        .glassCard()
    }

    private func vitalRow(_ name: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(name).font(.system(size: 13)).foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.7), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: loaded ? geo.size.width * min(max(value, 0), 1) : 0)
                        .shadow(color: color.opacity(0.7), radius: 5)
                }
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 0.8), value: value)
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
}

// MARK: - Botão com brilho (DESIGN_SYSTEM §8.3)

struct GlowButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.8))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.8)],
                                       startPoint: .top, endPoint: .bottom))
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8))
                .shimmer(period: 3.8)
                .shadow(color: Theme.accent.opacity(hovering ? 0.7 : 0.35),
                        radius: hovering ? 20 : 10, y: 4)
                .scaleEffect(hovering ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Card de ação inferior (DESIGN_SYSTEM §8)

struct ActionCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let value: String
    let valueSuffix: String
    var valueColor: Color = .white
    let linkTitle: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 46, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(color.opacity(0.35), lineWidth: 1))
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(color)
                    .shadow(color: color.opacity(0.9), radius: hovering ? 10 : 4)
            }
            .rotationEffect(.degrees(hovering ? -6 : 0))

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 4)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                (Text(value).font(.system(size: 19, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
                 + Text(" " + valueSuffix).font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)

                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(linkTitle).font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .offset(x: hovering ? 3 : 0)
                    }
                    .foregroundStyle(Theme.accent)
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .glassCard()
        .tilt3D(maxAngle: 7)
        .animation(.spring(duration: 0.3), value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture(perform: action)
    }
}
