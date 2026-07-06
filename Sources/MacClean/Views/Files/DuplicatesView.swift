import SwiftUI
import MacCleanKit

struct DuplicatesView: View {
    @Environment(AppState.self) private var appState
    @State private var results: [ScanResult] = []
    /// The grouped view model the UI renders. `results` is derived from this
    /// (its removable copies) and is what the cleaner acts on; `displayGroups`
    /// carries the kept-original info that `results` alone can't express.
    @State private var displayGroups: [DuplicateDisplayGroup] = []
    /// Which duplicate sets are expanded in the grouped results. Owned here so
    /// it survives the AnyView rebuild that happens on each checkbox toggle.
    @State private var expandedGroups: Set<UUID> = []
    @State private var selectedItems: Set<URL> = []
    @State private var keepStrategy: DuplicateDetection.KeepStrategy = .oldest
    @State private var isScanning = false
    @State private var scanProgress: Double = 0
    @State private var scanPhase = ""
    @State private var scanComplete = false
    @State private var completion: CleanSummary?
    @State private var cleaning: CleaningEngine.Progress?
    @State private var cleanTask: Task<Void, Never>?
    @State private var elapsedSeconds: Int = 0

    var body: some View {
        Group {
            if isScanning {
                scanningView
            } else if scanComplete && results.isEmpty {
                ModuleContainerView(
                    title: L10n.tr("重复文件", "Duplicatas"),
                    subtitle: "",
                    theme: .files,
                    emptyMessage: L10n.tr("未找到重复文件", "Nenhuma duplicata encontrada"),
                    results: results,
                    selectedItems: $selectedItems,
                    isScanning: false,
                    scanComplete: true,
                    completion: nil,
                    cleaning: cleaning,
                    onScan: scan, onClean: clean,
                    onCancelClean: { cleanTask?.cancel() },
                    onReset: reset
                )
            } else if !results.isEmpty {
                ModuleContainerView(
                    title: L10n.tr("重复文件", "Duplicatas"),
                    subtitle: "",
                    theme: .files,
                    results: results,
                    selectedItems: $selectedItems,
                    isScanning: false,
                    completion: completion,
                    cleaning: cleaning,
                    onScan: scan, onClean: clean,
                    onCancelClean: { cleanTask?.cancel() },
                    onReset: reset,
                    resultsContent: {
                        AnyView(
                            VStack(spacing: 0) {
                                keepStrategyBar
                                DuplicateGroupsList(
                                    groups: displayGroups,
                                    selectedItems: $selectedItems,
                                    expanded: $expandedGroups
                                )
                            }
                        )
                    }
                )
            } else if completion != nil {
                ModuleContainerView(
                    title: L10n.tr("重复文件", "Duplicatas"),
                    subtitle: "",
                    theme: .files,
                    results: [],
                    selectedItems: $selectedItems,
                    isScanning: false,
                    completion: completion,
                    cleaning: cleaning,
                    onScan: scan, onClean: clean,
                    onCancelClean: { cleanTask?.cancel() },
                    onReset: reset
                )
            } else {
                idleView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Lets the user choose which copy of each set to keep; the rest are
    /// re-selected for removal automatically.
    private var keepStrategyBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(Color.brand)
            Text(L10n.tr("保留副本", "Manter a cópia"))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.primary.opacity(0.8))
            Picker("", selection: $keepStrategy) {
                Text(L10n.tr("最旧", "Mais antiga")).tag(DuplicateDetection.KeepStrategy.oldest)
                Text(L10n.tr("最新", "Mais recente")).tag(DuplicateDetection.KeepStrategy.newest)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .labelsHidden()
            .onChange(of: keepStrategy) { _, _ in applyKeepStrategy() }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// Re-pick the kept copy in every group per `keepStrategy`, then re-select
    /// all the resulting removable copies.
    private func applyKeepStrategy() {
        let rebalanced = DuplicateDetection.rebalance(displayGroups, keep: keepStrategy)
        displayGroups = rebalanced
        let removable = rebalanced.flatMap(\.duplicates)
        results = removable.isEmpty
            ? []
            : [ScanResult(category: .duplicates, items: removable, autoSelect: false)]
        selectedItems = Set(removable.map(\.url))
    }

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text(L10n.tr("重复文件", "Duplicatas"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                Text(L10n.tr("使用渐进式 SHA-256 哈希检测\n查找重复文件", "Encontre arquivos duplicados usando detecção\nprogressiva por hash SHA-256"))
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 13))
                Text(L10n.tr("大型个人目录可能需要几分钟扫描", "Este escaneamento pode levar vários minutos em pastas pessoais grandes"))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ScanButton(title: L10n.tr("扫描", "Escanear"), subtitle: L10n.tr("重复文件", "Duplicatas"), theme: .files, action: scan)

            Spacer()
        }
    }

    private var scanningView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(.primary)
                .scaleEffect(1.4)

            VStack(spacing: 6) {
                Text(scanPhase)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.2), value: scanPhase)

                Text(L10n.tr("已用时：\(formatElapsed(elapsedSeconds))", "Decorrido: \(formatElapsed(elapsedSeconds))"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.6))
            }

            Text(L10n.tr("重复文件检测会使用 SHA-256 哈希每个候选文件。\n大型个人目录可能需要 5–15 分钟。", "A detecção de duplicatas calcula o hash SHA-256 de cada arquivo candidato.\nPastas pessoais grandes podem levar de 5 a 15 minutos."))
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func scan() {
        isScanning = true
        scanComplete = false
        scanProgress = 0
        elapsedSeconds = 0
        scanPhase = L10n.tr("正在扫描个人目录...", "Escaneando a pasta pessoal...")

        // Elapsed timer
        let timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds += 1
            }
        }

        Task {
            scanPhase = L10n.tr("正在扫描个人目录...", "Escaneando a pasta pessoal...")
            try? await Task.sleep(for: .milliseconds(400))

            scanPhase = L10n.tr("正在按大小分组文件...", "Agrupando arquivos por tamanho...")
            try? await Task.sleep(for: .milliseconds(400))

            scanPhase = L10n.tr("正在并行哈希候选文件...", "Calculando o hash dos arquivos candidatos em paralelo...")

            let module = DuplicatesModule()
            let groups = await module.scanDisplayGroups()

            scanPhase = L10n.tr("正在完成...", "Finalizando...")
            try? await Task.sleep(for: .milliseconds(300))

            timerTask.cancel()
            displayGroups = groups
            expandedGroups = []
            // The cleaner only ever sees the removable copies — never an
            // original — so a kept copy can't be deleted even by selecting all.
            let removable = groups.flatMap(\.duplicates)
            results = removable.isEmpty
                ? []
                : [ScanResult(category: .duplicates, items: removable, autoSelect: false)]
            // Pre-check every removable copy; the user unchecks anything to spare.
            selectedItems = Set(removable.map(\.url))
            isScanning = false
            scanComplete = true
        }
    }

    private func clean() {
        let preCleanSelectedCount = selectedItems.count
        cleaning = CleaningEngine.Progress(
            totalItems: preCleanSelectedCount,
            processedItems: 0, removedSoFar: 0, freedBytesSoFar: 0
        )
        cleanTask = Task {
            let result = await CleanActions.executeUserClean(
                results: results,
                selectedItems: selectedItems,
                engine: appState.cleaningEngine,
                onProgress: { progress in
                    Task { @MainActor in cleaning = progress }
                }
            )
            cleaning = nil
            completion = CleanSummary(
                selectedCount: preCleanSelectedCount,
                removedCount: result.removedCount,
                freedBytes: result.freedBytes,
                errorMessages: result.errors.map(\.error)
            )
        }
    }

    private func reset() {
        results = []; displayGroups = []; expandedGroups = []; selectedItems = []
        completion = nil; cleaning = nil; cleanTask = nil
        scanComplete = false; elapsedSeconds = 0
    }
}
