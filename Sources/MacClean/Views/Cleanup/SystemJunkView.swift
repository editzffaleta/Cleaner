import SwiftUI
import MacCleanKit

struct SystemJunkView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("removeBackgroundColors") private var removeBackgroundColors = false
    @State private var viewModel = SystemJunkViewModel()
    @State private var showLargeSelectionConfirm = false
    @State private var showActivityLog = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .results:
                resultsView
            case .empty:
                emptyView
            case .cleaning(let progress):
                cleaningView(progress: progress)
            case .done(let summary):
                doneView(summary: summary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let e = appState.scanResultsStore.entry(for: .systemJunk) {
                viewModel.restore(results: e.results, selection: e.selection, scanComplete: e.scanComplete)
            }
        }
        .onDisappear {
            appState.scanResultsStore.save(
                results: viewModel.results,
                selection: viewModel.selectedItems,
                scanComplete: viewModel.isScanComplete,
                for: .systemJunk
            )
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                    Text(L10n.tr("系统垃圾", "Lixo do Sistema"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)

                    Text(L10n.tr("查找并移除系统缓存、日志、\n语言文件和其他垃圾", "Encontre e remova caches do sistema, logs,\narquivos de idioma e outros lixos"))
                    .font(.system(size: 14))
                    .foregroundStyle(.primary.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            ScanButton(
                title: L10n.tr("扫描", "Escanear"),
                subtitle: L10n.tr("系统垃圾", "Lixo do Sistema"),
                theme: .cleanup
            ) {
                viewModel.startScan()
            }

            Spacer()
        }
    }

    private func scanningView(progress: Double) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ScanProgressRing(
                progress: progress,
                phase: viewModel.scanPhase,
                detail: L10n.tr("发现 \(viewModel.filesFound) 个文件", "\(viewModel.filesFound) arquivos encontrados"),
                theme: .cleanup
            )

            Spacer()
        }
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            HStack {
                SizeDisplay(size: viewModel.totalSelectedSize, label: L10n.tr("已选择待清理", "selecionados para limpar"))
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(L10n.tr("已选择 \(viewModel.selectedCount) / \(viewModel.totalFileCount) 个文件", "\(viewModel.selectedCount) de \(viewModel.totalFileCount) arquivos"))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.6))

                    Button(L10n.tr("清理", "Limpar")) {
                        if viewModel.selectedCount > MCConstants.cleanConfirmationThreshold {
                            showLargeSelectionConfirm = true
                        } else {
                            viewModel.startCleaning(engine: appState.cleaningEngine)
                        }
                    }
                    .buttonStyle(SuperEllipseButtonStyle(
                        gradient: ModuleTheme.cleanup.buttonGradient,
                        size: CGSize(width: 110, height: 40)
                    ))
                    // Prevent clicking Clean with nothing checked — that
                    // path used to drop the user into a misleading "0 bytes
                    // cleaned up" screen that looked like a failed clean.
                    .disabled(viewModel.selectedCount == 0)
                    .opacity(viewModel.selectedCount == 0 ? 0.5 : 1.0)
                    .help(viewModel.selectedCount == 0
                          ? L10n.tr("请至少勾选一个要清理的项目", "Marque ao menos um item para limpar")
                          : L10n.tr("将 \(viewModel.selectedCount) 项移到废纸篓", "Mover \(viewModel.selectedCount) item(ns) para a Lixeira"))
                    .alert(
                        L10n.tr("清理 \(viewModel.selectedCount.formatted()) 项？", "Limpar \(viewModel.selectedCount.formatted()) itens?"),
                        isPresented: $showLargeSelectionConfirm
                    ) {
                        Button(L10n.tr("取消", "Cancelar"), role: .cancel) { }
                        Button(L10n.tr("继续", "Continuar"), role: .destructive) {
                            viewModel.startCleaning(engine: appState.cleaningEngine)
                        }
                    } message: {
                        Text(L10n.tr("约 \(ByteCountFormatter.string(fromByteCount: Int64(viewModel.totalSelectedSize), countStyle: .file)) 数据，可能需要几分钟。清理过程中可以取消。", "São cerca de \(ByteCountFormatter.string(fromByteCount: Int64(viewModel.totalSelectedSize), countStyle: .file)) de dados e pode levar vários minutos. Você pode cancelar no meio da limpeza."))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            FileListView(
                results: viewModel.results,
                selectedItems: $viewModel.selectedItems
            )
            .background {
                if removeBackgroundColors { Color.clear }
                else { Rectangle().fill(.ultraThinMaterial) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary.opacity(0.9))
            Text(L10n.tr("未发现垃圾", "Nenhum lixo encontrado"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
            Text(L10n.tr("你的 Mac 很干净！", "Seu Mac está limpo!"))
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.55))
            Button(L10n.tr("完成", "Concluído")) { viewModel.reset() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private func cleaningView(progress: CleaningEngine.Progress?) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Determinate progress when the engine has emitted at least one
            // snapshot; indeterminate spinner before the first chunk lands.
            ScanProgressRing(
                progress: progress?.fraction ?? 0.0,
                phase: cleaningPhaseText(progress),
                theme: .cleanup
            )

            if let progress {
                Text(L10n.tr("已处理 \(progress.processedItems.formatted()) / \(progress.totalItems.formatted()) 项", "\(progress.processedItems.formatted()) de \(progress.totalItems.formatted()) itens"))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.65))
            }

            // Cancel button — engine honors Task.isCancelled at chunk
            // boundaries, so a cancel halts the operation and produces a
            // partial CleanResult (which the .done state shows honestly).
            Button(L10n.tr("取消", "Cancelar")) { viewModel.cancelCleaning() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)

            Spacer()
        }
    }

    /// See ModuleContainerView.cleanErrorDetail for the design rationale —
    /// this is the same UI, lifted here because SystemJunkView has its
    /// own state machine and doesn't route through ModuleContainerView.
    @ViewBuilder
    private func cleanErrorDetail(for summary: CleanSummary) -> some View {
        if summary.errorCount == 1, let msg = summary.firstErrorMessage {
            Text(msg)
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .textSelection(.enabled)
        } else if !summary.topErrorGroups.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.topErrorGroups, id: \.message) { group in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(group.count.formatted())×")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.6))
                            .frame(minWidth: 50, alignment: .trailing)
                        Text(group.message)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }
                }
                let shownTotal = summary.topErrorGroups.reduce(0) { $0 + $1.count }
                if summary.errorCount > shownTotal {
                    Text(L10n.tr("…以及另外 \((summary.errorCount - shownTotal).formatted()) 项", "…e mais \((summary.errorCount - shownTotal).formatted())"))
                        .font(.system(size: 11))
                        .foregroundStyle(.primary.opacity(0.5))
                        .padding(.top, 2)
                }
                Text(L10n.tr("完整日志：~/Library/Logs/MacClean/operations.log", "Log completo: ~/Library/Logs/MacClean/operations.log"))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.45))
                    .padding(.top, 4)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 24)
        }
    }

    private func cleaningPhaseText(_ progress: CleaningEngine.Progress?) -> String {
        guard let progress, progress.totalItems > 0 else {
            return L10n.tr("正在开始清理...", "Iniciando a limpeza...")
        }
        let pct = Int((progress.fraction * 100).rounded())
        return L10n.tr("正在清理… \(pct)%", "Limpando… \(pct)%")
    }

    private func doneView(summary: CleanSummary) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Three distinguishable end-states. The user-reported confusion
            // (the Reddit "0 bytes cleaned up" screenshot) was the second
            // case: scan surfaced items but they were all in autoSelect=false
            // categories (most commonly Universal Binaries) so nothing was
            // checked when Clean was clicked. Saying "0 bytes" looked broken;
            // saying "Nothing was selected" tells the user what to do next.
            if summary.selectedCount == 0 {
                Image(systemName: "checklist.unchecked")
                    .font(.system(size: 52))
                    .foregroundStyle(.primary.opacity(0.85))
                Text(L10n.tr("未选择任何项目", "Nada foi selecionado"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(L10n.tr("请重新扫描，勾选要移除的项目，然后点击“清理”。", "Refaça o escaneamento, marque os itens que deseja remover e clique em Limpar."))
                    .font(.system(size: 13))
                    .foregroundStyle(.primary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if summary.removedCount == 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange.opacity(0.85))
                Text(L10n.tr("\(summary.selectedCount) 项无法清理", "\(summary.selectedCount) item\(summary.selectedCount == 1 ? "" : "s") couldn't be cleaned"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                cleanErrorDetail(for: summary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.primary)
                SizeDisplay(size: summary.freedBytes, label: L10n.tr("已清理", "limpo"))
                    .foregroundStyle(.primary)
                if summary.removedCount < summary.selectedCount {
                    // Partial success — tell them what got skipped.
                    Text(L10n.tr("已移除 \(summary.removedCount) / \(summary.selectedCount) 项", "\(summary.removedCount) de \(summary.selectedCount) itens removidos") +
                         (summary.errorCount > 0 ? L10n.tr(" — \(summary.errorCount) 个错误", " — \(summary.errorCount) error\(summary.errorCount == 1 ? "" : "s")") : ""))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.65))
                }
            }

            HStack(spacing: 10) {
                if summary.errorCount > 0 {
                    Button {
                        showActivityLog = true
                    } label: {
                        Label(L10n.tr("查看日志", "Ver Registro"), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                    .help(L10n.tr("打开活动日志，查看每个错误并复制详情用于反馈问题", "Abra o registro de atividades para ver todos os erros e copiar detalhes para um relato de bug"))
                }
                Button(L10n.tr("完成", "Concluído")) { viewModel.reset() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
            }
            Spacer()
        }
        .sheet(isPresented: $showActivityLog) { LogViewerView() }
    }
}
