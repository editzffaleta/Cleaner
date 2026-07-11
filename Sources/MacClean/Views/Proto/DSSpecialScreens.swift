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

// MARK: - Lente de Espaço (analisador REAL de "Dados do Sistema" / dados de apps)
//
// O balde "Dados do Sistema" do macOS é dominado por dados REAIS dos apps —
// mídia do WhatsApp, perfis de navegador, imagens de VM, Docker — que ficam em
// ~/Library/{Application Support, Group Containers, Containers}. Um cleaner de
// lixo NÃO deve apagar isso sozinho (você perderia dados). Esta tela mede essas
// pastas com `du` (tamanho exato em disco), ranqueia da maior para a menor e
// deixa VOCÊ decidir — revelando cada uma no Finder. É o "onde meu espaço foi".

/// Uma pasta de dados encontrada pelo analisador.
struct SpaceEntry: Identifiable {
    let id = UUID()
    let name: String       // nome amigável do app (ex.: "WhatsApp")
    let url: URL           // caminho real da pasta
    let bytes: UInt64
    let kind: String       // rótulo: "Dados de App", "Contêiner", "Cache"…
    let icon: String
    let hint: String?      // dica de como reduzir com segurança, quando conhecida
    var protected = false  // container bloqueado por TCC — precisa de Acesso Total ao Disco
    var sizeText: String { FileSizeFormatter.format(bytes) }
}

struct DSSpaceLensScreen: View {
    private let accent = SidebarItem.spaceLens.dsAccent
    @State private var scanning = false
    @State private var entries: [SpaceEntry] = []
    @State private var scanned = false

    private var totalBytes: UInt64 { entries.reduce(0) { $0 + $1.bytes } }
    private var maxBytes: UInt64 { entries.map(\.bytes).max() ?? 1 }
    private var hasProtected: Bool { entries.contains { $0.protected } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DSModuleHeader(title: SidebarItem.spaceLens.title,
                           subtitle: SidebarItem.spaceLens.dsSubtitle,
                           buttonTitle: scanning ? nil : "Escanear",
                           accent: accent) { scan() }
                .reveal(delay: 0.02)

            if scanning {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large).tint(accent)
                    Text("Medindo suas pastas de dados… isso pode levar um minuto.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !entries.isEmpty {
                if hasProtected {
                    fdaBanner.padding(.horizontal, 30).reveal(delay: 0.04)
                }
                infoBanner.padding(.horizontal, 30).reveal(delay: 0.06)
                list
            } else if scanned {
                emptyState
            } else {
                introState
            }
        }
    }

    // Algumas pastas (WhatsApp etc.) são protegidas pelo macOS: sem Acesso Total
    // ao Disco, nem o app nem o próprio `du` conseguem medi-las ou limpá-las.
    private var fdaBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 18)).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Algumas pastas grandes estão bloqueadas pela privacidade do macOS")
                    .font(.system(size: 12.5, weight: .bold)).foregroundStyle(.white)
                Text("Conceda **Acesso Total ao Disco** ao Cleaner para medir e revelar containers protegidos (como o WhatsApp). Depois, escaneie de novo.")
                    .font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.75))
            }
            Spacer(minLength: 8)
            Button {
                PermissionManager.shared.openFullDiskAccessSettings()
            } label: {
                Text("Abrir Ajustes")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.black.opacity(0.85))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(.orange))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
    }

    // Aviso honesto: isto é dado real, não lixo.
    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16)).foregroundStyle(accent)
            Text("Isto são **dados reais dos seus apps**, não lixo. O Cleaner não apaga automaticamente — revise cada pasta e decida você mesmo. Comece pelas maiores.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.35), lineWidth: 1))
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                    DSSpaceRow(entry: entry, maxBytes: maxBytes, accent: accent)
                        .reveal(delay: 0.08 + Double(min(i, 8)) * 0.05)
                }
                HStack {
                    Text("Total analisado")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text(FileSizeFormatter.format(totalBytes))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 6).padding(.top, 4)
            }
            .padding(.horizontal, 30).padding(.top, 6).padding(.bottom, 26)
        }
    }

    private var introState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.35))
            Text("Clique em Escanear para descobrir quais apps ocupam\nseus \"Dados do Sistema\"")
                .multilineTextAlignment(.center)
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44)).foregroundStyle(dsGreen)
            Text("Nenhuma pasta de dados volumosa encontrada.")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: scan

    private func scan() {
        guard !scanning else { return }
        scanning = true
        scanned = true
        Task.detached(priority: .userInitiated) {
            let found = Self.analyze()
            await MainActor.run {
                withAnimation(.spring(duration: 0.5)) {
                    entries = found
                    scanning = false
                }
            }
        }
    }

    /// Mede as pastas de dados de app dentro de ~/Library e ranqueia por tamanho.
    /// Rodado fora do MainActor (Process + I/O de disco).
    private nonisolated static func analyze() -> [SpaceEntry] {
        let lib = MCConstants.home.appending(path: "Library")
        // Pastas cujos FILHOS são dados por app (cada app = uma pasta).
        let drillRoots: [(String, String)] = [
            ("Application Support", "Dados de App"),
            ("Group Containers", "Contêiner de grupo"),
            ("Containers", "Contêiner"),
        ]
        let drillNames = Set(drillRoots.map(\.0))

        var sized: [(url: URL, bytes: UInt64, kind: String)] = []
        var blocked: [(url: URL, kind: String)] = []

        func collect(root: URL, kind: String, skip: Set<String> = []) {
            let r = Self.childSizes(of: root)
            for (url, bytes) in r.sized where !skip.contains(url.lastPathComponent) {
                sized.append((url, bytes, kind))
            }
            for url in r.blocked where !skip.contains(url.lastPathComponent) {
                blocked.append((url, kind))
            }
        }

        for (folder, kind) in drillRoots {
            collect(root: lib.appending(path: folder), kind: kind)
        }
        // Demais itens de topo da Biblioteca (pnpm, Python, Caches…) como uma
        // linha cada, sem detalhar — evita duplicar as pastas já detalhadas.
        collect(root: lib, kind: "Biblioteca", skip: drillNames)

        // Pastas protegidas de TERCEIROS (WhatsApp etc.) SEMPRE aparecem, mesmo
        // sem tamanho — são justamente candidatas a maiores. Os containers de
        // sistema da Apple (group.com.apple.*) são minúsculos e não acionáveis:
        // filtramos para não poluir a lista. Apps conhecidos vêm primeiro; no
        // máximo 12 para não virar uma parede de "bloqueada".
        let protectedEntries: [SpaceEntry] = blocked
            .filter { !Self.isSystemContainer($0.url.lastPathComponent) }
            .map { item -> SpaceEntry in
                let raw = item.url.lastPathComponent
                return SpaceEntry(
                    name: friendlyAppName(raw), url: item.url, bytes: 0, kind: item.kind,
                    icon: appIcon(for: raw),
                    hint: "Conceda Acesso Total ao Disco para medir e revelar esta pasta.",
                    protected: true)
            }
            .sorted { a, b in
                let ak = isKnownApp(a.url.lastPathComponent), bk = isKnownApp(b.url.lastPathComponent)
                if ak != bk { return ak }          // apps conhecidos primeiro
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            .prefix(12)
            .map { $0 }

        // Itens mensuráveis: ≥ 50 MB, maior → menor.
        let minBytes: UInt64 = 50 * 1024 * 1024
        let sizedEntries: [SpaceEntry] = sized
            .filter { $0.bytes >= minBytes }
            .sorted { $0.bytes > $1.bytes }
            .map { item in
                let raw = item.url.lastPathComponent
                return SpaceEntry(
                    name: friendlyAppName(raw), url: item.url, bytes: item.bytes,
                    kind: item.kind, icon: appIcon(for: raw), hint: appHint(for: raw))
            }

        return Array((protectedEntries + sizedEntries).prefix(60))
    }

    /// Container de sistema da Apple — protegido mas minúsculo e não acionável.
    private nonisolated static func isSystemContainer(_ name: String) -> Bool {
        let l = name.lowercased()
        return l.contains("com.apple.") || l.contains("group.com.apple")
            || l.contains("developer.apple") || l.contains("apple.wwdc")
    }

    /// Tamanho exato (em disco) de cada subpasta imediata de `root`, via `du -sk`
    /// (uma chamada para todos os filhos — rápido e preciso, sem prompt de senha).
    /// Subpastas que o macOS bloqueia por privacidade (TCC) não emitem tamanho no
    /// stdout — nós as detectamos por ausência e devolvemos como `blocked`.
    private nonisolated static func childSizes(
        of root: URL
    ) -> (sized: [(URL, UInt64)], blocked: [URL]) {
        let fm = FileManager.default
        guard let kids = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) else { return ([], []) }
        let dirs = kids.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        guard !dirs.isEmpty else { return ([], []) }

        let p = Process()
        p.executableURL = URL(filePath: "/usr/bin/du")
        p.arguments = ["-sk"] + dirs.map { $0.path(percentEncoded: false) }
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()   // "Operation not permitted"/"Permission denied" descartados
        guard (try? p.run()) != nil else { return ([], []) }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        var sized: [(URL, UInt64)] = []
        var seen = Set<String>()
        if let s = String(data: data, encoding: .utf8) {
            for line in s.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2,
                      let kb = UInt64(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
                let path = String(parts[1])
                seen.insert(path)
                sized.append((URL(filePath: path), kb * 1024))
            }
        }
        // Filhos que existem mas não produziram tamanho = bloqueados pelo TCC.
        let blocked = dirs.filter { !seen.contains($0.path(percentEncoded: false)) }
        return (sized, blocked)
    }
}

/// Nomes bonitos para os apps mais comuns cujos identificadores (reverse-DNS ou
/// com prefixo de Team ID) não dizem nada ao usuário. Chave = trecho procurado
/// no nome bruto da pasta (minúsculo). Pura tabela — fácil de estender.
private let spaceKnownApps: [(match: String, name: String, icon: String, hint: String?)] = [
    ("whatsapp", "WhatsApp", "message.fill",
     "Apague mídias grandes em WhatsApp › Ajustes › Armazenamento e dados."),
    ("telegram", "Telegram", "paperplane.fill",
     "Limpe o cache em Telegram › Ajustes › Dados e Armazenamento."),
    ("docker", "Docker", "shippingbox.fill",
     "Use a tarefa \"Recuperar Espaço do Docker\" na aba Manutenção."),
    ("google.chrome", "Google Chrome", "globe", "Limpe os dados de navegação no próprio Chrome."),
    ("google", "Google", "globe", nil),
    ("brave", "Brave", "globe", "Limpe os dados de navegação no próprio Brave."),
    ("openai.atlas", "OpenAI Atlas", "globe", nil),
    ("discord", "Discord", "bubble.left.and.bubble.right.fill", nil),
    ("spotify", "Spotify", "music.note", "Reduza o cache de músicas nos Ajustes do Spotify."),
    ("minecraft", "Minecraft", "cube.fill", nil),
    ("claude", "Claude", "sparkle", nil),
    ("code", "VS Code", "chevron.left.forwardslash.chevron.right", nil),
    ("slack", "Slack", "number", nil),
    ("microsoft.excel", "Microsoft Excel", "tablecells", nil),
    ("onedrive", "OneDrive", "cloud.fill", nil),
    ("office", "Microsoft Office", "doc.fill", nil),
    ("drivefs", "Google Drive", "cloud.fill", nil),
    ("pnpm", "pnpm (Node)", "shippingbox", "Rode `pnpm store prune` no terminal."),
    ("python", "Python", "chevron.left.forwardslash.chevron.right", nil),
]

/// Nome amigável a partir do nome bruto da pasta.
func friendlyAppName(_ raw: String) -> String {
    let lower = raw.lowercased()
    if let hit = spaceKnownApps.first(where: { lower.contains($0.match) }) { return hit.name }
    // Sem correspondência conhecida: descasca Team ID e reverse-DNS.
    var s = raw
    if let dot = s.firstIndex(of: "."),
       s.distance(from: s.startIndex, to: dot) == 10,
       s[..<dot].allSatisfy({ $0.isNumber || ($0.isLetter && $0.isUppercase) }) {
        s = String(s[s.index(after: dot)...])
    }
    if s.hasPrefix("group.") { s = String(s.dropFirst(6)) }
    let noise: Set<String> = ["com", "net", "org", "io", "co", "ru", "us", "app",
                              "shared", "mac", "macos", "group", "suite"]
    let parts = s.split(separator: ".").map(String.init)
    if parts.count >= 2, noise.contains(parts[0].lowercased()) {
        for c in parts.reversed() where !noise.contains(c.lowercased()) {
            return c.prefix(1).uppercased() + c.dropFirst()
        }
    }
    return s
}

private func appIcon(for raw: String) -> String {
    let lower = raw.lowercased()
    if let hit = spaceKnownApps.first(where: { lower.contains($0.match) }) { return hit.icon }
    return "folder.fill"
}

/// True se o nome bruto casa com um app conhecido da tabela.
func isKnownApp(_ raw: String) -> Bool {
    let lower = raw.lowercased()
    return spaceKnownApps.contains { lower.contains($0.match) }
}

private func appHint(for raw: String) -> String? {
    let lower = raw.lowercased()
    return spaceKnownApps.first(where: { lower.contains($0.match) })?.hint
}

/// Uma linha do analisador: app, tamanho, barra proporcional e "Mostrar no Finder".
private struct DSSpaceRow: View {
    let entry: SpaceEntry
    let maxBytes: UInt64
    let accent: Color
    @State private var hovering = false

    private var fraction: Double {
        maxBytes > 0 ? Double(entry.bytes) / Double(maxBytes) : 0
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent.opacity(0.14))
                Image(systemName: entry.icon).font(.system(size: 16)).foregroundStyle(accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    Text(entry.kind.uppercased())
                        .font(.system(size: 8.5, weight: .heavy)).kerning(0.5)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.16)))
                }
                // Barra proporcional ao maior item.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule().fill(LinearGradient(colors: [accent, accent.opacity(0.6)],
                                                      startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * fraction))
                    }
                }
                .frame(height: 5)
                if let hint = entry.hint {
                    Text(hint).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if entry.protected {
                Text("bloqueada")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.9))
                Button {
                    PermissionManager.shared.openFullDiskAccessSettings()
                } label: {
                    Label("Conceder acesso", systemImage: "lock.open")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(.orange.opacity(hovering ? 1 : 0.85)))
                }
                .buttonStyle(.plain)
                .help("Abrir Ajustes › Privacidade › Acesso Total ao Disco")
            } else {
                Text(entry.sizeText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                } label: {
                    Label("Mostrar", systemImage: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(.white.opacity(hovering ? 0.16 : 0.08)))
                }
                .buttonStyle(.plain)
                .help("Revelar no Finder para revisar ou remover manualmente")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassCard(hoverLift: false)
        .onHover { hovering = $0 }
    }
}

// MARK: - Ajustes (chaves REAIS)

struct DSSettingsScreen: View {
    @Environment(AppState.self) private var appState
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

                sectionTitle("Histórico")
                card {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Histórico de Limpezas").font(.system(size: 15, weight: .medium))
                            Text("Veja quanto espaço você já liberou ao longo do tempo.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Abrir") { appState.selectedSidebarItem = .cleanupHistory }
                            .buttonStyle(.bordered)
                    }
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
