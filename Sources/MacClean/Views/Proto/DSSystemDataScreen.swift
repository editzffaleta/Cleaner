import SwiftUI
import AppKit
import MacCleanKit

// "Dados do Sistema" — o vilão do armazenamento em Macs. Junta os grandes
// contribuidores da categoria "Dados do Sistema"/"Outros" do macOS (caches,
// logs, backups iOS, lixo do Xcode, atualizações antigas, imagens de disco) E
// reduz os SNAPSHOTS LOCAIS DO TIME MACHINE — o maior espaço escondido, que o
// macOS guarda no seu próprio disco e nenhum outro módulo remove.

private let dsGreen = Color(red: 0.45, green: 0.85, blue: 0.60)

/// Uma linha da tela: ou um conjunto de arquivos (categoria real do scan) ou os
/// snapshots do Time Machine (tratados por comando, não por exclusão de arquivo).
struct SystemDataItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let detail: String
    let bytes: UInt64
    var selected: Bool
    enum Kind {
        case files(ScanCategory, [FileItem])
        case timeMachineSnapshots
    }
    let kind: Kind
    var sizeText: String { FileSizeFormatter.format(bytes) }
}

struct DSSystemDataScreen: View {
    @Environment(AppState.self) private var appState
    private let accent = SidebarItem.systemData.dsAccent

    private enum Stage { case scan, results, cleaning, finished }
    @State private var stage: Stage = .scan
    @State private var scanning = false
    @State private var items: [SystemDataItem] = []
    @State private var cleanProgress: Double = 0
    @State private var freedBytes: UInt64 = 0

    private var selectedBytes: UInt64 { items.filter(\.selected).reduce(0) { $0 + $1.bytes } }
    private var selectedText: String { FileSizeFormatter.format(selectedBytes) }

    var body: some View {
        ZStack {
            switch stage {
            case .scan: scanStage.transition(.flip3D)
            case .results, .cleaning: resultsStage.transition(.flip3D)
            case .finished: finishedStage.transition(.flip3D)
            }
        }
        .animation(.spring(duration: 0.7), value: stage)
    }

    // MARK: fase 1 — escanear

    private var scanStage: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(SidebarItem.systemData.title)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)],
                                                startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                .reveal(delay: 0.05)
            Text(SidebarItem.systemData.dsSubtitle)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 14)
                .reveal(delay: 0.15)
            Spacer()
            DSScanButton(caption: "Espaço escondido", scanning: $scanning,
                         work: { await runScan() }) {
                withAnimation(.spring(duration: 0.7)) { stage = .results }
            }
            .tilt3D(maxAngle: 8)
            .reveal(delay: 0.25)
            Spacer(); Spacer()
        }
        .padding(40)
    }

    private func runScan() async {
        var rows: [SystemDataItem] = []
        // 1) Contribuidores baseados em arquivo (categorias reais do Lixo do Sistema)
        let relevant: Set<ScanCategory> = [
            .userCaches, .systemCaches, .userLogs, .systemLogs,
            .iosDeviceBackups, .oldUpdates, .xcodeJunk, .ideCaches,
            .packageManagerCaches, .aiToolCaches, .unusedDiskImages, .documentVersions,
        ]
        let junk = await SystemJunkModule().scan()
        for r in junk where relevant.contains(r.category) && !r.items.isEmpty {
            rows.append(SystemDataItem(
                icon: dataIcon(for: r.category),
                name: r.category.displayName,
                detail: "\(r.items.count) " + (r.items.count == 1 ? "item" : "itens"),
                bytes: r.totalSize,
                selected: r.autoSelect,
                kind: .files(r.category, r.items)))
        }
        // 2) Snapshots locais do Time Machine (o grande vilão escondido)
        let snap = await Self.measureSnapshots()
        if snap.count > 0 && snap.bytes > 200 * 1024 * 1024 {
            rows.append(SystemDataItem(
                icon: "externaldrive.badge.timemachine",
                name: "Snapshots locais do Time Machine",
                detail: "\(snap.count) " + (snap.count == 1 ? "snapshot" : "snapshots") + " · espaço purgável",
                bytes: snap.bytes,
                selected: true,
                kind: .timeMachineSnapshots))
        }
        items = rows.sorted { $0.bytes > $1.bytes }
    }

    // MARK: fase 2 — resultados

    private var resultsStage: some View {
        VStack(spacing: 18) {
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56)).foregroundStyle(dsGreen).pulseGlow(dsGreen)
                    Text("Nada para limpar aqui!").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    Text("Seus Dados do Sistema já estão enxutos.").foregroundStyle(.white.opacity(0.6))
                    Button { withAnimation(.spring(duration: 0.7)) { stage = .scan } } label: {
                        Text("Voltar").font(.system(size: 13, weight: .bold)).foregroundStyle(.black.opacity(0.8))
                            .padding(.horizontal, 22).padding(.vertical, 10).background(Capsule().fill(accent))
                    }.buttonStyle(.plain).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dados do Sistema").font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                        Text("\(items.count) fontes de espaço · selecione o que recuperar")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Button { withAnimation(.spring(duration: 0.7)) { stage = .scan } } label: {
                        Label("Escanear Novamente", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(.white.opacity(0.1)))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 34).padding(.top, 44)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(Array($items.enumerated()), id: \.element.id) { i, $item in
                            DSSystemDataRow(item: $item, accent: accent)
                                .tilt3D(maxAngle: 3).reveal(delay: 0.1 + Double(i) * 0.07)
                        }
                    }
                    .padding(.horizontal, 34).padding(.vertical, 6)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedText)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced)).foregroundStyle(.white)
                            .contentTransition(.numericText()).animation(.snappy, value: selectedBytes)
                        Text("selecionado para recuperar").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    if stage == .cleaning {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("Limpando… \(Int(cleanProgress * 100))%")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                                .contentTransition(.numericText())
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.12))
                                    Capsule().fill(LinearGradient(colors: [accent, dsGreen], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * cleanProgress)
                                        .shadow(color: accent.opacity(0.8), radius: 6)
                                }
                            }.frame(width: 220, height: 8)
                        }
                    } else {
                        Button(action: clean) {
                            Label("Recuperar \(selectedText)", systemImage: "sparkles")
                                .font(.system(size: 14, weight: .bold)).foregroundStyle(.black.opacity(0.85))
                                .padding(.horizontal, 24).padding(.vertical, 12)
                                .background(Capsule().fill(LinearGradient(colors: [Color(red: 0.5, green: 0.92, blue: 0.65), Color(red: 0.35, green: 0.8, blue: 0.55)], startPoint: .top, endPoint: .bottom)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.4), lineWidth: 0.8))
                                .shimmer(period: 3.0)
                                .shadow(color: Color(red: 0.4, green: 0.85, blue: 0.6).opacity(0.5), radius: 16, y: 4)
                        }
                        .buttonStyle(.plain).disabled(selectedBytes == 0).opacity(selectedBytes == 0 ? 0.4 : 1)
                    }
                }
                .padding(.horizontal, 26).padding(.vertical, 18).glassCard(hoverLift: false)
                .padding(.horizontal, 34).padding(.bottom, 26)
            }
        }
    }

    // MARK: fase 3 — concluído

    private var finishedStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(dsGreen.opacity(0.15)).frame(width: 140, height: 140).pulseGlow(dsGreen)
                Image(systemName: "checkmark").font(.system(size: 52, weight: .heavy)).foregroundStyle(dsGreen)
            }
            Text("\(FileSizeFormatter.format(freedBytes)) recuperados!")
                .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
            Text("Mais espaço livre no seu Mac.").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
            Button {
                items = []
                withAnimation(.spring(duration: 0.7)) { stage = .scan }
            } label: {
                Text("Concluir").font(.system(size: 13, weight: .bold)).foregroundStyle(.black.opacity(0.8))
                    .padding(.horizontal, 26).padding(.vertical, 11).background(Capsule().fill(accent)).shimmer()
            }.buttonStyle(.plain).padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: limpeza REAL

    private func clean() {
        stage = .cleaning
        cleanProgress = 0
        let selected = items.filter(\.selected)
        let fileResults: [ScanResult] = selected.compactMap {
            if case let .files(cat, files) = $0.kind { return ScanResult(category: cat, items: files, autoSelect: true) }
            return nil
        }
        let fileURLs = Set(fileResults.flatMap { $0.items.map(\.url) })
        let snapshotItem = selected.first { if case .timeMachineSnapshots = $0.kind { return true }; return false }
        let engine = appState.cleaningEngine

        Task {
            var freed: UInt64 = 0
            if !fileResults.isEmpty {
                let r = await CleanActions.executeUserClean(
                    results: fileResults, selectedItems: fileURLs, engine: engine,
                    source: CleanHistorySource.systemJunk,
                    onProgress: { p in Task { @MainActor in cleanProgress = max(cleanProgress, p.fraction * 0.6) } })
                freed += r.freedBytes
            }
            // Snapshots do Time Machine via MaintenanceExecutor (pede senha de admin).
            if let snap = snapshotItem {
                await MainActor.run { cleanProgress = max(cleanProgress, 0.65) }
                let result = await MaintenanceExecutor().execute(.thinTimeMachineSnapshots)
                if result.success { freed += snap.bytes }
            }
            await MainActor.run {
                cleanProgress = 1
                freedBytes = freed
                NSSound(named: "Glass")?.play()
                withAnimation(.spring(duration: 0.7)) { stage = .finished }
            }
        }
    }

    // MARK: helpers

    /// Espaço purgável (majoritariamente snapshots locais) + contagem de snapshots.
    private static func measureSnapshots() async -> (bytes: UInt64, count: Int) {
        await Task.detached(priority: .utility) { () -> (UInt64, Int) in
            var bytes: UInt64 = 0
            if let v = try? URL(filePath: "/").resourceValues(
                forKeys: [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
                let now = UInt64(v.volumeAvailableCapacity ?? 0)
                let important = UInt64(v.volumeAvailableCapacityForImportantUsage ?? 0)
                bytes = important > now ? important - now : 0
            }
            var count = 0
            let p = Process()
            p.executableURL = URL(filePath: "/usr/bin/tmutil")
            p.arguments = ["listlocalsnapshots", "/"]
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            if (try? p.run()) != nil {
                p.waitUntilExit()
                if let d = try? out.fileHandleForReading.readToEnd(),
                   let s = String(data: d, encoding: .utf8) {
                    count = s.split(separator: "\n").filter { $0.contains("com.apple.TimeMachine") }.count
                }
            }
            return (bytes, count)
        }.value
    }

    private func dataIcon(for category: ScanCategory) -> String {
        switch category {
        case .userCaches, .systemCaches, .packageManagerCaches, .ideCaches, .aiToolCaches: "internaldrive"
        case .userLogs, .systemLogs: "doc.text"
        case .iosDeviceBackups: "iphone"
        case .oldUpdates: "arrow.down.circle"
        case .xcodeJunk: "hammer"
        case .unusedDiskImages: "opticaldisc"
        case .documentVersions: "clock.arrow.circlepath"
        default: "folder"
        }
    }
}

private struct DSSystemDataRow: View {
    @Binding var item: SystemDataItem
    let accent: Color
    @State private var hovering = false

    private var isSnapshot: Bool { if case .timeMachineSnapshots = item.kind { return true }; return false }

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
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.black.opacity(0.75)).transition(.scale)
                    }
                }
                .shadow(color: item.selected ? accent.opacity(0.6) : .clear, radius: 6)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(accent.opacity(0.14))
                    Image(systemName: item.icon).font(.system(size: 15)).foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(item.name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        if isSnapshot {
                            Text("GERENCIADO PELO macOS")
                                .font(.system(size: 8.5, weight: .heavy)).kerning(0.5)
                                .foregroundStyle(accent)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(accent.opacity(0.18)))
                        }
                    }
                    Text(item.detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                Spacer()
                Text(item.sizeText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.selected ? .white : .white.opacity(0.4))
            }
            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain).glassCard(hoverLift: false)
        .opacity(item.selected ? 1 : 0.6).onHover { hovering = $0 }
    }
}
