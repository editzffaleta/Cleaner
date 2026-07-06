import SwiftUI
import AppKit
import MacCleanKit

// Telas especializadas do protótipo, ligadas aos dados reais.

private let dsGreen = Color(red: 0.45, green: 0.85, blue: 0.60)
private let dsRed = Color(red: 1.0, green: 0.55, blue: 0.55)

// MARK: - Otimização (itens de início REAIS com toggles)

struct DSOptimizationScreen: View {
    private let accent = SidebarItem.optimization.dsAccent
    private let manager = AutoStartManager()
    @State private var tab = "Itens de Início"
    private let tabs = ["Itens de Início", "Launch Agents", "Launch Daemons"]
    @State private var items: [AutoStartItem] = []
    @State private var loading = true

    private var visible: [AutoStartItem] {
        switch tab {
        case "Launch Agents": items.filter { $0.sourceType == .launchAgent }
        case "Launch Daemons": items.filter { $0.sourceType == .launchDaemon }
        default: items.filter { $0.sourceType == .loginItem }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DSModuleHeader(title: SidebarItem.optimization.title,
                           subtitle: SidebarItem.optimization.dsSubtitle,
                           buttonTitle: "Atualizar", buttonIcon: "arrow.triangle.2.circlepath",
                           accent: accent) { refresh() }
                .reveal(delay: 0.02)

            HStack(spacing: 2) {
                ForEach(tabs, id: \.self) { t in
                    Button { withAnimation(.spring(duration: 0.3)) { tab = t } } label: {
                        Text(t)
                            .font(.system(size: 12, weight: tab == t ? .bold : .medium))
                            .foregroundStyle(tab == t ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(tab == t ? Color.white.opacity(0.14) : .clear))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.25)))
            .padding(.horizontal, 30)
            .reveal(delay: 0.10)

            Group {
                if loading {
                    VStack { Spacer(); ProgressView().tint(accent); Spacer() }
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(visible) { item in
                                DSOptimizationRow(item: item, accent: accent) { newVal in
                                    try? manager.toggleItem(item, enabled: newVal)
                                    refresh()
                                }
                            }
                            if visible.isEmpty {
                                Text("Nenhum item nesta categoria")
                                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                                    .padding(.vertical, 30)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .glassCard(hoverLift: false)
            .padding(.horizontal, 30)
            .padding(.bottom, 26)
            .reveal(delay: 0.18)
        }
        .task { refresh() }
    }

    private func refresh() {
        loading = items.isEmpty
        Task.detached(priority: .userInitiated) {
            let all = manager.getItems()
            await MainActor.run { items = all; loading = false }
        }
    }
}

private struct DSOptimizationRow: View {
    let item: AutoStartItem
    let accent: Color
    let onToggle: (Bool) -> Void
    @State private var hovering = false

    private var badgeColor: Color {
        switch item.sourceType {
        case .loginItem: Color(red: 0.35, green: 0.45, blue: 0.9)
        case .launchAgent: Color(red: 0.35, green: 0.7, blue: 0.5)
        case .launchDaemon: Color(red: 0.8, green: 0.5, blue: 0.3)
        }
    }

    private var badgeTextColor: Color {
        switch item.sourceType {
        case .loginItem: Color(red: 0.55, green: 0.7, blue: 1.0)
        case .launchAgent: Color(red: 0.6, green: 0.9, blue: 0.7)
        case .launchDaemon: Color(red: 1.0, green: 0.75, blue: 0.55)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.sourceType.localizedName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(badgeTextColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(badgeColor.opacity(0.25)))
            }

            Spacer()

            Toggle("", isOn: Binding(get: { item.isEnabled }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(accent)
                .disabled(item.isSystem)

            Button {
                if let path = item.configFilePath {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
                }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(hovering ? Color.white.opacity(0.05) : .clear))
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Manutenção (tarefas REAIS)

struct DSMaintenanceScreen: View {
    private let accent = SidebarItem.maintenance.dsAccent
    @State private var executor = MaintenanceExecutor()
    @State private var running: Set<MaintenanceTask> = []
    @State private var done: Set<MaintenanceTask> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            DSModuleHeader(title: SidebarItem.maintenance.title,
                           subtitle: SidebarItem.maintenance.dsSubtitle,
                           buttonTitle: "Executar Tarefas Seguras",
                           accent: accent) { runSafeTasks() }
                .reveal(delay: 0.02)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(MaintenanceTask.allCases.enumerated()), id: \.element.id) { i, task in
                        DSMaintenanceRow(task: task, accent: accent,
                                         running: running.contains(task),
                                         isDone: done.contains(task)) { run(task) }
                            .reveal(delay: 0.08 + Double(i) * 0.05)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 26)
            }
        }
    }

    private func run(_ task: MaintenanceTask) {
        guard !running.contains(task) else { return }
        running.insert(task)
        Task {
            _ = await executor.execute(task)
            running.remove(task)
            NSSound(named: "Glass")?.play()
            withAnimation(.spring) { _ = done.insert(task) }
        }
    }

    private func runSafeTasks() {
        for t in MaintenanceTask.allCases where t.severity == .safe { run(t) }
    }
}

private struct DSMaintenanceRow: View {
    let task: MaintenanceTask
    let accent: Color
    let running: Bool
    let isDone: Bool
    let run: () -> Void
    @State private var hovering = false

    private var advanced: Bool { task.severity != .safe }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.35), lineWidth: 1))
                Image(systemName: task.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    if advanced {
                        Text("AVANÇADO")
                            .font(.system(size: 8.5, weight: .heavy))
                            .kerning(0.5)
                            .foregroundStyle(dsRed)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(red: 0.9, green: 0.3, blue: 0.3).opacity(0.2)))
                    }
                }
                Text(task.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            if running {
                ProgressView().controlSize(.small).tint(accent)
            } else if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(dsGreen)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: run) {
                    Image(systemName: advanced ? "exclamationmark.triangle" : "play.circle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(advanced ? dsRed : accent)
                        .scaleEffect(hovering ? 1.15 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(hoverLift: false)
        .animation(.spring(duration: 0.25), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Desinstalador (apps REAIS)

struct DSUninstallerScreen: View {
    private let accent = SidebarItem.uninstaller.dsAccent
    private let discovery = AppDiscovery()
    private let pathFinder = AppPathFinder()
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var filter = "Todos"
    @State private var apps: [AppInfo] = []
    @State private var selected: AppInfo?
    @State private var associated: [FileItem] = []
    @State private var loadingFiles = false
    @State private var uninstalling = false
    @State private var confirmUninstall = false

    private var filtered: [AppInfo] {
        apps.filter { app in
            (query.isEmpty || app.name.localizedCaseInsensitiveContains(query))
            && (filter != "Não usado" || app.isUnused)
            && (filter != "Terceiros" || !app.isAppleApp)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DSModuleHeader(title: SidebarItem.uninstaller.title,
                           subtitle: SidebarItem.uninstaller.dsSubtitle,
                           accent: accent)
                .reveal(delay: 0.02)

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
                    TextField("Buscar apps...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 11).fill(.black.opacity(0.25)))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.1), lineWidth: 1))

                HStack(spacing: 2) {
                    ForEach(["Todos", "Não usado", "Terceiros"], id: \.self) { f in
                        Button { withAnimation(.spring(duration: 0.3)) { filter = f } } label: {
                            Text(f)
                                .font(.system(size: 12, weight: filter == f ? .bold : .medium))
                                .foregroundStyle(filter == f ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(filter == f ? Color.white.opacity(0.15) : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 11).fill(.black.opacity(0.25)))
            }
            .padding(.horizontal, 30)
            .reveal(delay: 0.10)

            HStack(spacing: 16) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(filtered) { app in
                            DSUninstallerRow(app: app, accent: accent,
                                             selected: selected?.id == app.id) { select(app) }
                        }
                    }
                    .padding(10)
                }
                .frame(maxWidth: .infinity)
                .glassCard(hoverLift: false)

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassCard(hoverLift: false)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 26)
            .reveal(delay: 0.18)
        }
        .task {
            apps = await discovery.discoverApps()
        }
        .alert("Mover \(selected?.name ?? "o app") para a Lixeira?", isPresented: $confirmUninstall) {
            Button("Cancelar", role: .cancel) {}
            Button("Desinstalar", role: .destructive) { uninstall() }
        } message: {
            Text("O app e seus arquivos associados serão movidos para a Lixeira.")
        }
    }

    private func select(_ app: AppInfo) {
        selected = app
        associated = []
        loadingFiles = true
        Task.detached(priority: .userInitiated) {
            let files = pathFinder.findAssociatedFiles(for: app)
            await MainActor.run { associated = files; loadingFiles = false }
        }
    }

    private func uninstall() {
        guard let app = selected, !uninstalling else { return }
        uninstalling = true
        let files = associated
        let engine = appState.cleaningEngine
        Task {
            try? FileManager.default.trashItem(at: app.path, resultingItemURL: nil)
            _ = await CleanActions.executeUserClean(
                items: files, selectedItems: Set(files.map(\.url)),
                engine: engine, source: CleanHistorySource.uninstaller)
            apps = await discovery.discoverApps()
            selected = nil
            associated = []
            uninstalling = false
            NSSound(named: "Glass")?.play()
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let app = selected {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path(percentEncoded: false)))
                        .resizable().interpolation(.high)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.name).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Text(FileSizeFormatter.format(app.size))
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                }

                Divider().overlay(.white.opacity(0.1))

                if loadingFiles {
                    HStack { Spacer(); ProgressView().controlSize(.small).tint(accent); Spacer() }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            fileRow("app.fill", "Aplicativo", FileSizeFormatter.format(app.size))
                            ForEach(associated.prefix(12)) { f in
                                fileRow(f.isDirectory ? "folder" : "doc.text", f.name,
                                        FileSizeFormatter.format(f.size))
                            }
                            if associated.count > 12 {
                                Text("…e mais \(associated.count - 12) arquivos")
                                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                }

                Spacer()

                Button { confirmUninstall = true } label: {
                    Group {
                        if uninstalling {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Label("Desinstalar Completamente", systemImage: "trash")
                                .font(.system(size: 13, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 11)
                        .fill(LinearGradient(colors: [Color(red: 0.9, green: 0.35, blue: 0.35),
                                                      Color(red: 0.75, green: 0.25, blue: 0.3)],
                                             startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Color.red.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(uninstalling)
            }
            .padding(20)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
                Text("Selecione um app para ver seus arquivos")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func fileRow(_ icon: String, _ name: String, _ size: String) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(accent).frame(width: 18)
            Text(name).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            Spacer()
            Text(size).font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 2)
    }
}

private struct DSUninstallerRow: View {
    let app: AppInfo
    let accent: Color
    let selected: Bool
    let select: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path.path(percentEncoded: false)))
                    .resizable().interpolation(.medium)
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(FileSizeFormatter.format(app.size))
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if app.isUnused {
                    Text("Não usado")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(selected ? accent.opacity(0.22) : hovering ? Color.white.opacity(0.05) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }
}

// MARK: - Atualizador (dados REAIS via appcast)

struct DSUpdaterScreen: View {
    private let accent = SidebarItem.updater.dsAccent
    @State private var checking = false
    @State private var checked = false
    @State private var updates: [AppUpdateChecker.AppUpdate] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DSModuleHeader(title: SidebarItem.updater.title,
                           subtitle: SidebarItem.updater.dsSubtitle,
                           buttonTitle: "Verificar Atualizações",
                           accent: accent) { check() }
                .reveal(delay: 0.02)

            if checking {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(accent)
                    Text("Verificando atualizações…")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !checked {
                VStack(spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Clique acima para verificar atualizações")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if updates.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(dsGreen)
                    Text("Todos os apps estão atualizados")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(Array(updates.enumerated()), id: \.element.id) { i, u in
                            HStack(spacing: 14) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: u.app.path.path(percentEncoded: false)))
                                    .resizable().interpolation(.medium)
                                    .frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.app.name).font(.system(size: 13.5, weight: .bold)).foregroundStyle(.white)
                                    Text("\(u.currentVersion)  →  \(u.availableVersion ?? "?")")
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer()
                                Button {
                                    if let url = u.downloadURL { NSWorkspace.shared.open(url) }
                                } label: {
                                    Text("Atualizar")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Color.black.opacity(0.8))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(accent))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .glassCard(hoverLift: false)
                            .reveal(delay: Double(i) * 0.07)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 26)
                }
            }
        }
    }

    private func check() {
        guard !checking else { return }
        checking = true
        Task {
            let apps = await AppDiscovery().discoverApps()
            let found = await AppUpdateChecker().checkForUpdates(apps: apps)
            withAnimation(.spring) {
                updates = found.filter(\.hasUpdate)
                checking = false
                checked = true
            }
        }
    }
}

// MARK: - Lente de Espaço (tamanhos REAIS, sem prompts de permissão)

struct DSSpaceLensScreen: View {
    private let accent = SidebarItem.spaceLens.dsAccent
    @State private var scanning = false
    @State private var blocks: [(String, UInt64, Color)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DSModuleHeader(title: SidebarItem.spaceLens.title,
                           subtitle: SidebarItem.spaceLens.dsSubtitle,
                           buttonTitle: "Escanear",
                           accent: accent) { scan() }
                .reveal(delay: 0.02)

            if scanning {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(accent)
                    Text("Mapeando o disco…").font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !blocks.isEmpty {
                treemap
                    .padding(.horizontal, 30)
                    .padding(.bottom, 26)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.35))
                    Text("Clique em Escanear para visualizar o uso do disco")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var treemap: some View {
        GeometryReader { geo in
            let total = max(blocks.reduce(0) { $0 + $1.1 }, 1)
            let top = Array(blocks.prefix(2))
            let bottom = Array(blocks.dropFirst(2))
            let topTotal = max(top.reduce(0) { $0 + $1.1 }, 1)
            let bottomTotal = max(bottom.reduce(0) { $0 + $1.1 }, 1)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Array(top.enumerated()), id: \.offset) { i, b in
                        DSTreemapBlock(name: b.0, bytes: b.1, color: b.2,
                                       width: (geo.size.width - 12) * CGFloat(Double(b.1) / Double(topTotal)))
                            .reveal(delay: Double(i) * 0.08)
                    }
                }
                .frame(height: geo.size.height * CGFloat(Double(topTotal) / Double(total)))

                HStack(spacing: 6) {
                    ForEach(Array(bottom.enumerated()), id: \.offset) { i, b in
                        DSTreemapBlock(name: b.0, bytes: b.1, color: b.2,
                                       width: (geo.size.width - 18) * CGFloat(Double(b.1) / Double(bottomTotal)))
                            .reveal(delay: 0.24 + Double(i) * 0.08)
                    }
                }
                .frame(height: geo.size.height * CGFloat(Double(bottomTotal) / Double(total)))
            }
        }
    }

    private func scan() {
        guard !scanning else { return }
        scanning = true
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let home = MCConstants.home
            let apps = dirSizeCapped(URL(filePath: "/Applications"))
            let library = dirSizeCapped(home.appending(path: "Library"), maxFiles: 120_000)
            var free: UInt64 = 0, total: UInt64 = 0
            if let vals = try? URL(filePath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
                total = UInt64(vals.volumeTotalCapacity ?? 0)
                free = UInt64(vals.volumeAvailableCapacityForImportantUsage ?? 0)
            }
            _ = fm
            let used = total > free ? total - free : 0
            let known = apps + library
            let system = used > known ? used - known : 0
            let result: [(String, UInt64, Color)] = [
                ("Sistema e outros", system, Color(red: 0.35, green: 0.5, blue: 0.95)),
                ("Aplicativos", apps, Color(red: 0.6, green: 0.45, blue: 0.95)),
                ("Biblioteca do usuário", library, Color(red: 0.35, green: 0.8, blue: 0.7)),
                ("Livre", free, Color(white: 0.5)),
            ].filter { $0.1 > 0 }
            await MainActor.run {
                withAnimation(.spring) {
                    blocks = result
                    scanning = false
                }
            }
        }
    }
}

private struct DSTreemapBlock: View {
    let name: String
    let bytes: UInt64
    let color: Color
    let width: CGFloat
    @State private var hovering = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.6)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(hovering ? 0.5 : 0.15), lineWidth: 1))
            .overlay(
                VStack(spacing: 2) {
                    Text(name)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(FileSizeFormatter.format(bytes))
                        .font(.system(size: 10.5, design: .monospaced))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(4))
            .frame(width: max(52, width))
            .shadow(color: color.opacity(hovering ? 0.6 : 0.25), radius: hovering ? 14 : 6, y: 3)
            .tilt3D(maxAngle: 10)
            .scaleEffect(hovering ? 1.02 : 1)
            .animation(.spring(duration: 0.25), value: hovering)
            .onHover { hovering = $0 }
    }
}

// MARK: - Ajustes (chaves REAIS)

struct DSSettingsScreen: View {
    @AppStorage("automaticUpdateChecks") private var autoUpdate = true
    @AppStorage("launchAtLogin") private var openAtLogin = false
    @AppStorage("showMenuBarWidget") private var showMenuBar = true
    @AppStorage("removeBackgroundColors") private var removeBackgrounds = false
    @AppStorage(AppLanguage.defaultsKey, store: SharedAppState.defaults) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(AppearanceManager.defaultsKey) private var themeRaw = AppearanceMode.dark.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MCConstants.appName).font(.system(size: 24, weight: .bold))
                            Text("Versão \(MCConstants.appVersion)").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Verificar Atualizações") {
                            NSWorkspace.shared.open(MCConstants.releasesURL)
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    Toggle("Verificar atualizações automaticamente", isOn: $autoUpdate)
                        .toggleStyle(.switch)
                        .font(.system(size: 15, weight: .medium))
                }

                sectionTitle("Geral")
                card {
                    settingRow(
                        title: "Abrir no login",
                        subtitle: "Abrir o Cleaner automaticamente quando você entrar no macOS.",
                        isOn: $openAtLogin)
                        .onChange(of: openAtLogin) { _, v in
                            Task { await LaunchAtLoginManager.shared.setEnabled(v) }
                        }

                    Divider()

                    settingRow(
                        title: "Mostrar o Cleaner na barra de menus",
                        subtitle: "CPU, memória, disco, bateria e rede ao vivo no topo da tela.",
                        isOn: $showMenuBar)
                        .onChange(of: showMenuBar) { _, v in
                            Task { await MenuBarLauncher.shared.setEnabled(v) }
                        }

                    HStack(spacing: 8) {
                        Image(systemName: showMenuBar ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(showMenuBar ? .green : .secondary)
                        Text("Status do widget:").foregroundStyle(.secondary)
                        Text(showMenuBar ? "Em execução" : "Desativado")
                            .font(.system(.body, design: .monospaced))
                    }
                    .font(.callout)
                }

                sectionTitle("Idioma da Interface")
                card {
                    HStack {
                        Text("Idioma").font(.system(size: 15, weight: .medium))
                        Spacer()
                        Picker("", selection: $languageRaw) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.pickerLabel).tag(lang.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    Text("As alterações se aplicam imediatamente à janela principal e ao widget da barra de menus.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                sectionTitle("Aparência")
                card {
                    HStack {
                        Text("Tema").font(.system(size: 15, weight: .medium))
                        Spacer()
                        Picker("", selection: $themeRaw) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .onChange(of: themeRaw) { _, _ in AppearanceManager.applyStored() }
                    }

                    Divider()

                    settingRow(
                        title: "Remover cores de fundo",
                        subtitle: "Substituir os fundos em gradiente dos módulos por uma cor escura neutra para melhor legibilidade.",
                        isOn: $removeBackgrounds)
                }
            }
            .padding(32)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
    }

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) { content() }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }

    private func settingRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .medium))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).toggleStyle(.switch).labelsHidden()
        }
    }
}
