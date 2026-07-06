import SwiftUI
import AppKit
import MacCleanKit

@main
struct MacCleanMenuApp: App {
    init() {
        AppLanguage.registerDefault(.system)
        // Single-instance enforcement. macOS does NOT auto-deduplicate
        // LSUIElement apps by bundle id the way it does for regular apps,
        // and we have two launch paths (SMAppService + NSWorkspace). If a
        // sibling instance is already running, terminate self immediately
        // so the user never sees two icons in the menu bar.
        // Only enforce when we have a real bundle id (i.e. running from
        // the .app). Under `swift run` the bare executable has no bundle
        // id, and matching against other nil-bundle processes would make
        // the dev build exit immediately.
        if let myBundleID = Bundle.main.bundleIdentifier {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let duplicate = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == myBundleID && $0.processIdentifier != myPID
            }
            if duplicate { exit(0) }
        }
    }

    // Polling runs continuously from launch in MenuStatsModel (started by the
    // app delegate), NOT from the popover's onAppear (see MenuStatsModel for
    // why). The App just observes the model and renders it.
    @NSApplicationDelegateAdaptor(MenuAppDelegate.self) private var appDelegate
    @State private var model = MenuStatsModel.shared
    @AppStorage(AppLanguage.defaultsKey, store: SharedAppState.defaults) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fallback
    }

    /// Menu-bar label icon: the Cleaner logo, in color, at 18px. Rendered as a
    /// normal (non-template) image so it shows the brand colors instead of
    /// being flattened to a monochrome mask.
    private static let labelIcon: NSImage = {
        let img = VacuumAsset.image.copy() as! NSImage
        img.isTemplate = false
        img.size = NSSize(width: 18, height: 18)
        return img
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                stats: model.stats,
                networkSpeed: model.networkSpeed,
                devices: model.devices,
                protection: model.protection,
                tips: model.tips,
                topApps: model.topApps,
                onDismissTip: { model.dismissTip(id: $0) }
            )
            .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
            .id(appLanguage.rawValue)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: Self.labelIcon)
                    .renderingMode(.original)
                if let stats = model.stats {
                    Text(FileSizeFormatter.format(stats.diskFree))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Palette (Midnight / turquoise)

enum MenuPalette {
    static let accent   = Color(red: 0.07, green: 0.737, blue: 0.780)   // #12bcc7
    static let bgBase   = Color(red: 0.027, green: 0.031, blue: 0.051)  // #07080d
    static let surface  = Color(red: 0.118, green: 0.157, blue: 0.212)  // #1e2836
    static let surface2 = Color(red: 0.086, green: 0.122, blue: 0.169)  // #161f2b
    static let border   = Color.white.opacity(0.08)

    static let green  = Color(red: 0.204, green: 0.827, blue: 0.600)    // #34d399
    static let amber  = Color(red: 0.961, green: 0.714, blue: 0.220)    // #f5b638
    static let red    = Color(red: 0.949, green: 0.333, blue: 0.373)    // #f2555f
    static let teal   = Color(red: 0.176, green: 0.831, blue: 0.749)    // #2dd4bf

    static let textPrimary = Color(red: 0.949, green: 0.945, blue: 0.969)
    static let muted       = Color(red: 0.576, green: 0.631, blue: 0.706) // #93a1b4

    /// Value → color on a green→amber→red scale (for CPU/memory/disk rings).
    static func loadColor(_ v: Double) -> Color {
        if v >= 0.85 { return red }
        if v >= 0.65 { return amber }
        return green
    }
}

// MARK: - Popover

struct MenuContentView: View {
    let stats: SystemStatsCollector.SystemStats?
    let networkSpeed: NetworkSpeedMonitor.NetworkSpeed?
    let devices: ConnectedDevices?
    let protection: SharedAppState.ProtectionStatus?
    let tips: [TipsEngine.Tip]
    let topApps: [RunningAppInfo]
    let onDismissTip: (String) -> Void

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                if let stats {
                    healthCard(stats)
                    statGrid(stats)
                    activityHeader
                    chips(stats)
                    if !tips.isEmpty { recommendationCard }
                    connectedCard
                    footer
                } else {
                    ProgressView().controlSize(.small).tint(MenuPalette.accent)
                        .frame(height: 120)
                    footer
                }
            }
        }
        .frame(width: 380)
    }

    private var background: some View {
        ZStack {
            MenuPalette.bgBase
            RadialGradient(colors: [MenuPalette.accent.opacity(0.20), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 300)
            RadialGradient(colors: [Color(red: 0.145, green: 0.47, blue: 0.86).opacity(0.13), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 280)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LinearGradient(
                    colors: [MenuPalette.accent.opacity(0.65).blend(withWhite: 0.5), MenuPalette.accent],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                }
                .shadow(color: MenuPalette.accent.opacity(0.5), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(MCConstants.appName)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(MenuPalette.textPrimary)
                HStack(spacing: 6) {
                    PulsingDot()
                    Text(L10n.tr("实时统计", "Estatísticas ao vivo"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MenuPalette.muted)
                }
            }
            Spacer()
            iconButton(symbol: "gearshape.fill") { TipAction.open(moduleID: "settings") }
                .help(L10n.tr("设置", "Ajustes"))
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        .padding(.bottom, 13)
        .background(
            LinearGradient(colors: [MenuPalette.accent.opacity(0.15), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private func iconButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MenuPalette.muted)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(MenuPalette.border, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: System health

    private func healthCard(_ s: SystemStatsCollector.SystemStats) -> some View {
        let h = SystemHealth.evaluate(s)
        return HStack(spacing: 11) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(h.color)
                .frame(width: 34, height: 34)
                .background(h.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("系统健康", "Saúde do Sistema"))
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(MenuPalette.muted)
                HStack(spacing: 7) {
                    Text(h.label)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(h.color)
                    Text(h.detail)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(MenuPalette.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            HealthBars(level: h.level)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .cardSurface()
        .padding(.horizontal, 15)
        .padding(.top, 2)
    }

    // MARK: Stat grid (rings)

    private func statGrid(_ s: SystemStatsCollector.SystemStats) -> some View {
        let diskUsed = s.diskTotal > 0 ? Double(s.diskTotal - s.diskFree) / Double(s.diskTotal) : 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
            ringCard(icon: "cpu", label: "CPU", value: s.cpuUsage,
                     color: MenuPalette.loadColor(s.cpuUsage),
                     sub: s.cpuUsage >= 0.75 ? L10n.tr("负载高", "Carga alta") : L10n.tr("负载正常", "Carga normal"))
            ringCard(icon: "memorychip", label: L10n.tr("内存", "Memória"), value: s.memoryPressure,
                     color: MenuPalette.loadColor(s.memoryPressure),
                     sub: FileSizeFormatter.format(s.memoryUsed),
                     action: (L10n.tr("优化", "Otimizar"), "maintenance"))
            ringCard(icon: "internaldrive", label: L10n.tr("磁盘", "Disco"), value: diskUsed,
                     color: MenuPalette.loadColor(diskUsed),
                     sub: L10n.tr("\(FileSizeFormatter.format(s.diskFree)) 可用", "\(FileSizeFormatter.format(s.diskFree)) livres"),
                     action: (L10n.tr("清理", "Liberar"), "system-junk"))
            if let level = s.batteryLevel {
                ringCard(icon: s.batteryIsCharging ? "battery.100.bolt" : "battery.75",
                         label: L10n.tr("电池", "Bateria"), value: level,
                         color: level > 0.2 ? MenuPalette.teal : MenuPalette.red,
                         sub: s.batteryIsCharging ? L10n.tr("充电中", "Carregando") : L10n.tr("放电中", "Na bateria"))
            } else {
                uptimeCard(s)
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func ringCard(icon: String, label: String, value: Double, color: Color, sub: String, action: (label: String, module: String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 12.5, weight: .bold)).foregroundStyle(MenuPalette.textPrimary)
                Spacer(minLength: 2)
                if let action {
                    Button { TipAction.open(moduleID: action.module) } label: {
                        Text(action.label).font(.system(size: 11, weight: .bold)).foregroundStyle(MenuPalette.accent)
                    }.buttonStyle(.plain)
                }
            }
            RingGauge(value: value, color: color, percent: "\(Int((value*100).rounded()))")
                .frame(width: 84, height: 84)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            Text(sub)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(MenuPalette.muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.top, 7)
        }
        .padding(12)
        .cardSurface()
    }

    private func uptimeCard(_ s: SystemStatsCollector.SystemStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "clock").font(.system(size: 12, weight: .semibold)).foregroundStyle(MenuPalette.teal)
                Text(L10n.tr("运行时间", "Tempo ativo")).font(.system(size: 12.5, weight: .bold)).foregroundStyle(MenuPalette.textPrimary)
                Spacer(minLength: 2)
            }
            Text(formatUptime(s.uptime))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(MenuPalette.textPrimary)
                .frame(width: 84, height: 84)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            Text(L10n.tr("已开机", "Ligado"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(MenuPalette.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 7)
        }
        .padding(12)
        .cardSurface()
    }

    // MARK: Activity

    private var activityHeader: some View {
        HStack {
            Text(L10n.tr("活动", "Atividade"))
                .font(.system(size: 10.5, weight: .bold)).tracking(0.5)
                .foregroundStyle(MenuPalette.muted)
            Spacer()
        }
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func chips(_ s: SystemStatsCollector.SystemStats) -> some View {
        HStack(spacing: 7) {
            chip(icon: "arrow.down", value: networkSpeed?.formattedIn ?? "—")
            chip(icon: "arrow.up", value: networkSpeed?.formattedOut ?? "—")
            chip(icon: "clock", value: formatUptime(s.uptime))
            chip(icon: "arrow.triangle.swap", value: s.swapUsed > 0 ? FileSizeFormatter.format(s.swapUsed) : FileSizeFormatter.format(s.memoryUsed))
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 13)
    }

    private func chip(icon: String, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(MenuPalette.muted)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(MenuPalette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(MenuPalette.surface2, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(MenuPalette.border, lineWidth: 0.5)
        }
    }

    // MARK: Recommendation

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(tips.prefix(1)) { tip in
                HStack(spacing: 7) {
                    Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundStyle(MenuPalette.amber)
                    Text(L10n.tr("建议", "Recomendação"))
                        .font(.system(size: 11, weight: .heavy)).tracking(0.9)
                        .foregroundStyle(MenuPalette.amber)
                    Spacer()
                    Button { onDismissTip(tip.id) } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(MenuPalette.muted)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }.buttonStyle(.plain).help(L10n.tr("30 天内不再显示", "Dispensar por 30 dias"))
                }
                Text(tip.title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(MenuPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 9)
                Text(tip.body).font(.system(size: 12)).foregroundStyle(MenuPalette.muted)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 3)
                Button { TipAction.open(moduleID: MenuTipRouting.moduleID(forTipID: tip.id)) } label: {
                    Text(tipCTA(tip))
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Color(red: 0.227, green: 0.149, blue: 0.0))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(
                            LinearGradient(colors: [Color(red: 0.973, green: 0.776, blue: 0.353), Color(red: 0.929, green: 0.635, blue: 0.122)],
                                           startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }.buttonStyle(.plain).padding(.top, 11)
            }
        }
        .padding(13)
        .background(
            LinearGradient(colors: [MenuPalette.amber.opacity(0.13), MenuPalette.amber.opacity(0.03)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(MenuPalette.amber.opacity(0.24), lineWidth: 1)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 13)
    }

    private func tipCTA(_ tip: TipsEngine.Tip) -> String {
        switch tip.id {
        case "trash_large": return L10n.tr("清空废纸篓", "Esvaziar Lixeira")
        case "caches_large": return L10n.tr("释放空间", "Liberar espaço")
        default: return L10n.tr("打开 \(MCConstants.appName)", "Abrir o \(MCConstants.appName)")
        }
    }

    // MARK: Connected (apps + external hardware)

    private var connectedCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(MenuPalette.muted)
                Text(L10n.tr("已连接", "Conectados")).font(.system(size: 12.5, weight: .bold)).foregroundStyle(MenuPalette.textPrimary)
                Spacer()
                Text("\(topApps.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(MenuPalette.muted)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(MenuPalette.surface2, in: Capsule())
                    .overlay { Capsule().strokeBorder(MenuPalette.border, lineWidth: 0.5) }
            }
            .padding(.horizontal, 13).padding(.top, 11).padding(.bottom, 7)

            ForEach(topApps) { app in
                HStack(spacing: 10) {
                    AppAvatar(app: app)
                    Text(app.name).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(MenuPalette.textPrimary)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 6)
                    Text(FileSizeFormatter.format(app.memory))
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(MenuPalette.muted)
                }
                .padding(.horizontal, 13).padding(.vertical, 7)
                .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.04)) }
            }

            hardwareRow(icon: "externaldrive.fill",
                        label: L10n.tr("外置磁盘", "Discos externos"),
                        trailing: externalVolumesSummary)
            if let d = devices, d.externalDisplays > 0 {
                hardwareRow(icon: "display",
                            label: L10n.tr("\(d.externalDisplays) 台外接显示器", "\(d.externalDisplays) monitor\(d.externalDisplays == 1 ? "" : "es") externo\(d.externalDisplays == 1 ? "" : "s")"),
                            trailing: nil)
            }
        }
        .cardSurface()
        .padding(.horizontal, 15)
        .padding(.bottom, 13)
    }

    private var externalVolumesSummary: String {
        guard let d = devices, !d.externalVolumes.isEmpty else {
            return L10n.tr("未连接", "Nenhum conectado")
        }
        if d.externalVolumes.count == 1 {
            return FileSizeFormatter.format(d.externalVolumes[0].freeBytes) + L10n.tr(" 可用", " livres")
        }
        return L10n.tr("\(d.externalVolumes.count) 个", "\(d.externalVolumes.count) conectados")
    }

    private func hardwareRow(icon: String, label: String, trailing: String?) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(MenuPalette.muted)
            Text(label).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(MenuPalette.muted)
            Spacer()
            if let trailing {
                Text(trailing).font(.system(size: 11, weight: .semibold)).foregroundStyle(MenuPalette.muted.opacity(0.85))
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 8)
        .overlay(alignment: .top) { Divider().overlay(Color.white.opacity(0.06)) }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 9) {
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 15, weight: .bold)).foregroundStyle(MenuPalette.red)
                    .frame(width: 40, height: 40)
                    .background(MenuPalette.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MenuPalette.red.opacity(0.28), lineWidth: 1) }
            }.buttonStyle(.plain).help(L10n.tr("退出 \(MCConstants.appName)", "Sair do \(MCConstants.appName)"))

            Button { TipAction.open() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 13, weight: .bold))
                    Text(L10n.tr("打开 \(MCConstants.appName)", "Abrir o \(MCConstants.appName)")).font(.system(size: 13.5, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(
                    LinearGradient(colors: [MenuPalette.accent.blend(withWhite: 0.08), MenuPalette.accent.blend(withBlack: 0.28)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: MenuPalette.accent.opacity(0.55), radius: 10, y: 5)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 15).padding(.top, 11).padding(.bottom, 15)
        .background(
            LinearGradient(colors: [.clear, Color.black.opacity(0.22)], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) { Divider().overlay(MenuPalette.border) }
    }

    // MARK: Helpers

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600, m = (Int(seconds) % 3600) / 60
        if h > 24 { return L10n.tr("\(h/24)天 \(h%24)小时", "\(h/24)d \(h%24)h") }
        return L10n.tr("\(h)小时 \(m)分", "\(h)h \(m)m")
    }
}

// MARK: - System health status

struct SystemHealth {
    enum Level { case good, fair, poor }
    let level: Level
    let label: String
    let detail: String
    let color: Color

    static func evaluate(_ s: SystemStatsCollector.SystemStats) -> SystemHealth {
        let diskUsed = s.diskTotal > 0 ? Double(s.diskTotal - s.diskFree) / Double(s.diskTotal) : 0
        if diskUsed >= 0.95 || s.memoryPressure >= 0.90 {
            return SystemHealth(level: .poor, label: L10n.tr("欠佳", "Crítico"),
                                detail: diskUsed >= 0.95 ? L10n.tr("磁盘几乎已满", "Disco quase cheio") : L10n.tr("内存压力过高", "Memória sob pressão"),
                                color: MenuPalette.red)
        }
        if diskUsed >= 0.85 || s.memoryPressure >= 0.75 || s.cpuUsage >= 0.90 {
            let detail: String
            if diskUsed >= 0.85 { detail = L10n.tr("磁盘几乎已满", "Disco quase cheio") }
            else if s.memoryPressure >= 0.75 { detail = L10n.tr("内存压力较高", "Pressão de memória") }
            else { detail = L10n.tr("CPU 负载高", "CPU sob carga") }
            return SystemHealth(level: .fair, label: L10n.tr("一般", "Regular"), detail: detail, color: MenuPalette.amber)
        }
        return SystemHealth(level: .good, label: L10n.tr("良好", "Ótimo"),
                            detail: L10n.tr("一切正常", "Tudo funcionando bem"), color: MenuPalette.green)
    }
}

struct HealthBars: View {
    let level: SystemHealth.Level

    private var color: Color {
        switch level { case .good: MenuPalette.green; case .fair: MenuPalette.amber; case .poor: MenuPalette.red }
    }
    /// How many of the five bars are lit for each level.
    private var lit: Int {
        switch level { case .good: 5; case .fair: 3; case .poor: 2 }
    }
    private let heights: [CGFloat] = [12, 17, 22, 17, 12]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < lit ? color : Color.white.opacity(0.12))
                    .frame(width: 5, height: heights[i])
            }
        }
    }
}

// MARK: - Pulsing "live" dot

struct PulsingDot: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(MenuPalette.green)
            .frame(width: 7, height: 7)
            .opacity(on ? 0.45 : 1)
            .shadow(color: MenuPalette.green.opacity(on ? 0 : 0.6), radius: on ? 5 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { on = true } }
    }
}

// MARK: - App avatar (real icon, letter fallback)

struct AppAvatar: View {
    let app: RunningAppInfo
    var body: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().interpolation(.high)
            } else {
                Text(String(app.name.prefix(1)).uppercased())
                    .font(.system(size: 12.5, weight: .heavy)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MenuPalette.accent)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Ring gauge (with glow)

struct RingGauge: View {
    let value: Double
    let color: Color
    let percent: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.45), radius: 4)
                .animation(.spring(response: 0.9, dampingFraction: 0.85), value: value)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(percent)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(MenuPalette.textPrimary)
                Text("%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(MenuPalette.textPrimary.opacity(0.55))
            }
        }
    }
}

// MARK: - Surface card modifier & color blends

extension View {
    func cardSurface(cornerRadius: CGFloat = 15) -> some View {
        self
            .background(MenuPalette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(MenuPalette.border, lineWidth: 0.5)
            }
    }
}

extension Color {
    /// Mix toward white / black by `amount` (0…1) — small helpers for the
    /// gradient highlights and shadows, so we don't hardcode extra constants.
    func blend(withWhite amount: Double) -> Color {
        blend(with: .white, amount: amount)
    }
    func blend(withBlack amount: Double) -> Color {
        blend(with: .black, amount: amount)
    }
    private func blend(with other: Color, amount: Double) -> Color {
        let a = max(0, min(1, amount))
        let n1 = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        let n2 = NSColor(other).usingColorSpace(.sRGB) ?? .gray
        return Color(
            red: Double(n1.redComponent) * (1 - a) + Double(n2.redComponent) * a,
            green: Double(n1.greenComponent) * (1 - a) + Double(n2.greenComponent) * a,
            blue: Double(n1.blueComponent) * (1 - a) + Double(n2.blueComponent) * a
        )
    }
}
