import SwiftUI
import AppKit
import MacCleanKit

// Telas do protótipo do usuário (teste swift/Cleaner), portadas verbatim e
// ligadas aos dados/motores reais. UI = mockup; dados = app real.

private let dsGreen = Color(red: 0.45, green: 0.85, blue: 0.60)

// MARK: - Subtítulos por módulo (Models.swift do protótipo)

extension SidebarItem {
    var dsSubtitle: String {
        switch self {
        case .home, .settings, .cleanupHistory: return ""
        case .smartScan: return "Escaneie seu Mac em busca de arquivos de lixo,\nameaças de malware e problemas de desempenho."
        case .systemJunk: return "Encontre e remova caches do sistema, logs,\narquivos de idioma e outros lixos"
        case .systemData: return "Recupere o espaço da categoria \"Dados do Sistema\":\ncaches, backups iOS e snapshots do Time Machine"
        case .mailAttachments: return "Localize e remova anexos e downloads do Mail"
        case .trashBins: return "Esvazie todas as lixeiras do seu Mac de uma vez"
        case .malwareRemoval: return "Verifique seu Mac em busca de malware, adware e spyware"
        case .privacy: return "Limpe históricos de navegação, cookies e itens recentes"
        case .optimization: return "Gerencie itens de login e agentes de inicialização"
        case .maintenance: return "Execute scripts de manutenção e reindexações do sistema"
        case .uninstaller: return "Remova aplicativos completamente, sem deixar restos"
        case .updater: return "Mantenha seus aplicativos sempre atualizados"
        case .spaceLens: return "Veja onde os GB de \"Dados do Sistema\" foram parar:\nas pastas de dados dos seus apps, do maior ao menor"
        case .largeOldFiles: return "Encontre arquivos grandes e antigos esquecidos no disco"
        case .duplicates: return "Localize arquivos duplicados e cópias semelhantes"
        case .shredder: return "Apague arquivos de forma segura e irrecuperável"
        }
    }
}

// MARK: - Cabeçalho padrão dos módulos (protótipo)

struct DSModuleHeader: View {
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var buttonIcon: String? = nil
    var accent: Color = Theme.accent
    var action: () -> Void = {}
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.8)],
                                       startPoint: .top, endPoint: .bottom))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            if let buttonTitle {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if let buttonIcon { Image(systemName: buttonIcon).font(.system(size: 12, weight: .semibold)) }
                        Text(buttonTitle).font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.black.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(colors: [accent, accent.opacity(0.82)],
                                                 startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.3), lineWidth: 0.8))
                    .shimmer(period: 4.2)
                    .shadow(color: accent.opacity(hovering ? 0.65 : 0.3), radius: hovering ? 18 : 9, y: 3)
                    .scaleEffect(hovering ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .animation(.spring(duration: 0.25), value: hovering)
                .onHover { hovering = $0 }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 46)
    }
}

// MARK: - Tela de módulo (scan → resultados → limpeza) com dados reais

/// Linha de resultado: uma categoria real do scan.
struct DSJunkItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let detail: String
    let sizeBytes: UInt64
    var selected = true
    let category: ScanCategory
    let files: [FileItem]

    var sizeText: String { FileSizeFormatter.format(sizeBytes) }
}

/// Módulos reais que alimentam cada tela genérica de scan.
@MainActor
private func realScanModules(for item: SidebarItem) -> [any ScanModule] {
    switch item {
    case .smartScan: [SystemJunkModule(), MailAttachmentsModule(), TrashBinsModule(), PrivacyModule()]
    case .systemJunk: [SystemJunkModule()]
    case .mailAttachments: [MailAttachmentsModule()]
    case .trashBins: [TrashBinsModule()]
    case .malwareRemoval: [MalwareModule()]
    case .privacy: [PrivacyModule()]
    case .largeOldFiles: [LargeOldFilesModule()]
    case .duplicates: [DuplicatesModule()]
    default: []
    }
}

/// Ícone da linha derivado da categoria real.
private func dsIcon(for category: ScanCategory) -> String {
    let n = category.displayName.lowercased()
    if n.contains("cache") { return "internaldrive" }
    if n.contains("log") { return "doc.text" }
    if n.contains("idioma") || n.contains("language") { return "globe" }
    if n.contains("xcode") { return "hammer" }
    if n.contains("lixeira") || n.contains("trash") { return "trash" }
    if n.contains("anexo") || n.contains("mail") { return "paperclip" }
    if n.contains("histórico") || n.contains("safari") || n.contains("navega") { return "safari" }
    if n.contains("cookie") { return "circle.grid.2x2" }
    if n.contains("duplicata") { return "doc.on.doc" }
    if n.contains("malware") || n.contains("ameaça") { return "shield.lefthalf.filled" }
    if n.contains("grande") || n.contains("antigo") { return "doc.richtext" }
    if n.contains("prefer") { return "gearshape.2" }
    if n.contains("binár") { return "cpu" }
    return "folder"
}

struct DSModuleScreen: View {
    let module: SidebarItem
    @Environment(AppState.self) private var appState

    private enum Stage { case scan, results, cleaning, finished }
    @State private var stage: Stage = .scan
    @State private var scanning = false
    @State private var items: [DSJunkItem] = []
    @State private var cleanProgress: Double = 0
    @State private var freedBytes: UInt64 = 0

    private var selectedBytes: UInt64 { items.filter(\.selected).reduce(0) { $0 + $1.sizeBytes } }
    private var selectedText: String { FileSizeFormatter.format(selectedBytes) }

    var body: some View {
        ZStack {
            switch stage {
            case .scan:
                scanStage.transition(.flip3D)
            case .results, .cleaning:
                resultsStage.transition(.flip3D)
            case .finished:
                finishedStage.transition(.flip3D)
            }
        }
        .animation(.spring(duration: 0.7), value: stage)
    }

    // MARK: fase 1 — botão de scan (real)

    private var scanStage: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(module.title)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [.white, .white.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                .reveal(delay: 0.05)

            Text(module.dsSubtitle)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 14)
                .reveal(delay: 0.15)

            Spacer()

            DSScanButton(caption: module == .smartScan ? "Limpeza com um clique" : module.title,
                         scanning: $scanning,
                         work: { await runRealScan() }) {
                withAnimation(.spring(duration: 0.7)) { stage = .results }
            }
            .tilt3D(maxAngle: 8)
            .reveal(delay: 0.25)

            Spacer()
            Spacer()
        }
        .padding(40)
    }

    /// Escaneia com os módulos reais e converte cada categoria em uma linha.
    private func runRealScan() async {
        var rows: [DSJunkItem] = []
        for mod in realScanModules(for: module) {
            let results = await mod.scan()
            for r in results where !r.items.isEmpty {
                rows.append(DSJunkItem(
                    icon: dsIcon(for: r.category),
                    name: r.category.displayName,
                    detail: "\(r.items.count) " + (r.items.count == 1 ? "item" : "itens"),
                    sizeBytes: r.totalSize,
                    selected: r.autoSelect || module == .duplicates || module == .trashBins,
                    category: r.category,
                    files: r.items
                ))
            }
        }
        items = rows.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    // MARK: fase 2 — resultados (reais)

    private var resultsStage: some View {
        VStack(spacing: 18) {
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(dsGreen)
                        .pulseGlow(dsGreen)
                    Text("Tudo limpo!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Nenhum item encontrado no seu Mac.")
                        .foregroundStyle(.white.opacity(0.6))
                    Button { withAnimation(.spring(duration: 0.7)) { stage = .scan } } label: {
                        Text("Voltar")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .padding(.horizontal, 22).padding(.vertical, 10)
                            .background(Capsule().fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resultados")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(items.count) categorias encontradas · selecione o que remover")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button { withAnimation(.spring(duration: 0.7)) { stage = .scan } } label: {
                        Label("Escanear Novamente", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 34)
                .padding(.top, 44)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(Array($items.enumerated()), id: \.element.id) { i, $item in
                            DSJunkRow(item: $item, accent: module.dsAccent)
                                .tilt3D(maxAngle: 3)
                                .reveal(delay: 0.1 + Double(i) * 0.07)
                        }
                    }
                    .padding(.horizontal, 34)
                    .padding(.vertical, 6)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedText)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: selectedBytes)
                        Text("selecionado para remoção")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()

                    if stage == .cleaning {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Limpando… \(Int(cleanProgress * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                                .contentTransition(.numericText())
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.12))
                                    Capsule()
                                        .fill(LinearGradient(colors: [Theme.accent, dsGreen],
                                                             startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * cleanProgress)
                                        .shadow(color: Theme.accent.opacity(0.8), radius: 6)
                                }
                            }
                            .frame(width: 220, height: 8)
                        }
                    } else {
                        Button(action: clean) {
                            Label("Limpar \(selectedText)", systemImage: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .padding(.horizontal, 24).padding(.vertical, 12)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(colors: [Color(red: 0.5, green: 0.92, blue: 0.65),
                                                                Color(red: 0.35, green: 0.8, blue: 0.55)],
                                                       startPoint: .top, endPoint: .bottom)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 0.8))
                                .shimmer(period: 3.0)
                                .shadow(color: Color(red: 0.4, green: 0.85, blue: 0.6).opacity(0.5), radius: 16, y: 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedBytes == 0)
                        .opacity(selectedBytes == 0 ? 0.4 : 1)
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .glassCard(hoverLift: false)
                .padding(.horizontal, 34)
                .padding(.bottom, 26)
            }
        }
    }

    // MARK: fase 3 — concluído (real)

    private var finishedStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(dsGreen.opacity(0.15))
                    .frame(width: 140, height: 140)
                    .pulseGlow(dsGreen)
                Image(systemName: "checkmark")
                    .font(.system(size: 52, weight: .heavy))
                    .foregroundStyle(dsGreen)
            }
            Text("\(FileSizeFormatter.format(freedBytes)) liberados!")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("Seu Mac agradece.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            Button {
                items = []
                withAnimation(.spring(duration: 0.7)) { stage = .scan }
            } label: {
                Text("Concluir")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .padding(.horizontal, 26).padding(.vertical, 11)
                    .background(Capsule().fill(Theme.accent))
                    .shimmer()
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Limpeza REAL via CleanActions (Lixeira primeiro, SafetyGuard etc.).
    private func clean() {
        stage = .cleaning
        cleanProgress = 0
        let selected = items.filter(\.selected)
        let results = selected.map { ScanResult(category: $0.category, items: $0.files, autoSelect: true) }
        let urls = Set(selected.flatMap { $0.files.map(\.url) })
        let engine = appState.cleaningEngine
        Task {
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: urls,
                engine: engine,
                source: module == .smartScan ? CleanHistorySource.smartScan : CleanHistorySource.manual,
                onProgress: { p in Task { @MainActor in cleanProgress = p.fraction } }
            )
            freedBytes = result.freedBytes
            NSSound(named: "Glass")?.play()
            withAnimation(.spring(duration: 0.7)) { stage = .finished }
        }
    }
}

// MARK: linha de resultado (protótipo)

private struct DSJunkRow: View {
    @Binding var item: DSJunkItem
    let accent: Color
    @State private var hovering = false

    var body: some View {
        Button { withAnimation(.snappy) { item.selected.toggle() } } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item.selected ? accent : .clear)
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(item.selected ? accent : .white.opacity(0.3), lineWidth: 1.5))
                        .frame(width: 20, height: 20)
                    if item.selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(Color.black.opacity(0.75))
                            .transition(.scale)
                    }
                }
                .shadow(color: item.selected ? accent.opacity(0.6) : .clear, radius: 6)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: item.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(item.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Text(item.sizeText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.selected ? .white : .white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(hoverLift: false)
        .opacity(item.selected ? 1 : 0.6)
        .onHover { hovering = $0 }
    }
}

// MARK: - Botão de escanear (protótipo, com trabalho real)

struct DSScanButton: View {
    let caption: String
    @Binding var scanning: Bool
    /// Trabalho real executado durante o escaneamento. O progresso visual
    /// avança de forma irregular mas só completa quando o trabalho termina.
    var work: (() async -> Void)? = nil
    var onComplete: () -> Void = {}

    private enum Phase { case idle, scanning, done }
    @State private var phase: Phase = .idle
    @State private var progress: Double = 0
    @State private var hovering = false
    @State private var breathe = false
    @State private var ripple = false
    @State private var rippleSeed = 0
    @State private var timer: Timer?
    @State private var workDone = false

    private let green = Color(red: 0.45, green: 0.90, blue: 0.60)

    var body: some View {
        Button(action: startScan) {
            ZStack {
                Circle()
                    .fill((phase == .done ? green : Theme.accent).opacity(0.25))
                    .frame(width: 250, height: 250)
                    .blur(radius: 42)
                    .scaleEffect(breathe ? 1.18 : 0.88)

                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Theme.accent.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 180, height: 180)
                        .scaleEffect(ripple ? 1.9 : 0.95)
                        .opacity(ripple ? 0 : 0.8)
                        .animation(
                            ripple ? .easeOut(duration: 1.2).delay(Double(i) * 0.18) : nil,
                            value: ripple)
                }
                .id(rippleSeed)

                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let speed: Double = phase == .scanning ? 90 : hovering ? 40 : 14

                    ZStack {
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [.clear, Theme.accent.opacity(0.1),
                                             Theme.accent, .white.opacity(0.9), .clear],
                                    center: .center),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 226, height: 226)
                            .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 360) * speed))

                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [1, 7]))
                            .foregroundStyle(.white.opacity(0.3))
                            .frame(width: 212, height: 212)
                            .rotationEffect(.degrees(-t.truncatingRemainder(dividingBy: 360) * speed * 0.4))

                        ForEach(0..<3, id: \.self) { i in
                            let angle = t * (phase == .scanning ? 2.2 : 0.5)
                                        + Double(i) * (.pi * 2 / 3)
                            Circle()
                                .fill(.white)
                                .frame(width: i == 0 ? 5 : 3.5, height: i == 0 ? 5 : 3.5)
                                .shadow(color: Theme.accent, radius: 4)
                                .offset(x: cos(angle) * 113, y: sin(angle) * 113)
                                .opacity(0.9)
                        }
                    }
                }
                .frame(width: 240, height: 240)

                VortexField(tint: Theme.accent, active: phase == .scanning)
                    .frame(width: 340, height: 340)

                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 5)
                    .frame(width: 196, height: 196)
                    .opacity(phase == .scanning ? 1 : 0)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.white, Theme.accent],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 196, height: 196)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .white.opacity(0.6), radius: 6)
                    .opacity(phase == .scanning ? 1 : 0)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: phase == .done
                                ? [green, green.opacity(0.7)]
                                : [Theme.accent, Theme.accent.opacity(0.72)],
                            center: .init(x: 0.3, y: 0.25),
                            startRadius: 10, endRadius: 190)
                    )
                    .frame(width: 172, height: 172)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.65), .clear],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.2)
                    )
                    .shadow(color: (phase == .done ? green : Theme.accent)
                        .opacity(breathe ? 0.8 : 0.4),
                            radius: breathe ? 50 : 26)

                Group {
                    switch phase {
                    case .idle:
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 34, weight: .semibold))
                            Text("Escanear")
                                .font(.system(size: 22, weight: .bold))
                            Text(caption)
                                .font(.system(size: 11, weight: .semibold))
                                .opacity(0.85)
                        }
                    case .scanning:
                        VStack(spacing: 2) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.15), value: Int(progress * 100))
                            Text("Escaneando…")
                                .font(.system(size: 12, weight: .semibold))
                                .opacity(0.85)
                        }
                    case .done:
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 38, weight: .heavy))
                                .transition(.scale.combined(with: .opacity))
                            Text("Concluído!")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            }
            .scaleEffect(hovering && phase == .idle ? 1.05 : 1)
            .animation(.spring(duration: 0.3), value: hovering)
            .animation(.spring(duration: 0.4), value: phase)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func startScan() {
        guard phase == .idle else { return }
        phase = .scanning
        scanning = true
        progress = 0
        workDone = work == nil

        rippleSeed += 1
        ripple = false
        DispatchQueue.main.async { ripple = true }

        // dispara o trabalho REAL em paralelo
        if let work {
            Task {
                await work()
                await MainActor.run { workDone = true }
            }
        }

        // progresso irregular; segura em 93% até o trabalho real terminar
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            // A Timer scheduled on the main run loop always fires on the main
            // thread, but its closure is typed `@Sendable` (no actor
            // association), so under strict Swift 6 concurrency it can't touch
            // the @MainActor view state directly. Assert the isolation we know
            // holds at runtime. We invalidate via the stored `timer` (same
            // object) rather than the closure's `t` param, so no non-Sendable
            // value is sent across the isolation boundary.
            MainActor.assumeIsolated {
                let step = Double.random(in: 0.004...0.028)
                let cap = workDone ? 1.0 : 0.93
                progress = min(cap, progress + step)
                if progress >= 1 {
                    timer?.invalidate()
                    withAnimation(.spring(duration: 0.5)) { phase = .done }
                    NSSound(named: "Glass")?.play()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        onComplete()
                        withAnimation(.easeOut(duration: 0.5)) {
                            phase = .idle
                            scanning = false
                            ripple = false
                        }
                    }
                }
            }
        }
    }
}
