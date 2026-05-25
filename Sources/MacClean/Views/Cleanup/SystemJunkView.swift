import SwiftUI
import MacCleanKit

struct SystemJunkView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SystemJunkViewModel()

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle:
                idleView
            case .scanning(let progress):
                scanningView(progress: progress)
            case .results:
                resultsView
            case .cleaning:
                cleaningView
            case .done(let freed):
                doneView(freed: freed)
            }
        }
        .padding(20)
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("System Junk")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Find and remove system caches, logs, language files, and other junk")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            ScanButton(
                title: "Scan",
                subtitle: "System Junk",
                theme: .cleanup,
                isScanning: false
            ) {
                viewModel.startScan()
            }

            Spacer()
        }
    }

    private func scanningView(progress: Double) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ScanButton(
                title: "Scan",
                theme: .cleanup,
                isScanning: true,
                progress: progress
            ) {}

            VStack(spacing: 4) {
                Text("Scanning for system junk...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)

                Text("\(viewModel.filesFound) files found")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                SizeDisplay(size: viewModel.totalSelectedSize, label: "selected to clean")
                    .foregroundStyle(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.selectedCount) of \(viewModel.totalFileCount) files")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))

                    Button("Clean") {
                        viewModel.startCleaning(engine: appState.cleaningEngine)
                    }
                    .buttonStyle(SuperEllipseButtonStyle(
                        gradient: ModuleTheme.cleanup.gradient,
                        size: CGSize(width: 120, height: 44)
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // File list
            FileListView(
                results: viewModel.results,
                selectedItems: $viewModel.selectedItems
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var cleaningView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView("Cleaning...")
                .foregroundStyle(.white)
                .tint(.white)
            Spacer()
        }
    }

    private func doneView(freed: UInt64) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)

            SizeDisplay(size: freed, label: "cleaned up")
                .foregroundStyle(.white)

            Button("Done") {
                viewModel.reset()
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Spacer()
        }
    }
}
