import SwiftUI
import MacCleanKit

struct SmartScanView: View {
    @Environment(AppState.self) private var appState
    @State private var scanState: SmartScanState = .idle

    enum SmartScanState {
        case idle
        case scanning(phase: String, progress: Double, filesFound: Int, sizeFound: UInt64)
        case results(cleanup: UInt64, protection: Int, performance: Int, totalSize: UInt64, moduleResults: [ModuleScanResult])
        case cleaning(progress: Double)
        case done(freedSize: UInt64)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            switch scanState {
            case .idle:
                idleView
            case .scanning(let phase, let progress, let filesFound, let sizeFound):
                scanningView(phase: phase, progress: progress, filesFound: filesFound, sizeFound: sizeFound)
            case .results(_, _, _, let totalSize, _):
                resultsView(totalSize: totalSize)
            case .cleaning(let progress):
                cleaningView(progress: progress)
            case .done(let freedSize):
                doneView(freedSize: freedSize)
            }

            Spacer()
        }
        .padding(40)
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Smart Scan")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Scan your Mac for junk files, malware threats, and performance issues")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            ScanButton(
                title: "Scan",
                subtitle: "One-click cleanup",
                theme: .smartScan,
                isScanning: false,
                action: startScan
            )
        }
    }

    private func scanningView(phase: String, progress: Double, filesFound: Int, sizeFound: UInt64) -> some View {
        VStack(spacing: 32) {
            ScanButton(
                title: "Scan",
                theme: .smartScan,
                isScanning: true,
                progress: progress,
                action: {}
            )

            VStack(spacing: 8) {
                Text(phase)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)

                HStack(spacing: 20) {
                    Label("\(filesFound) files", systemImage: "doc")
                    Label(FileSizeFormatter.format(sizeFound), systemImage: "internaldrive")
                }
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func resultsView(totalSize: UInt64) -> some View {
        VStack(spacing: 32) {
            SizeDisplay(size: totalSize, label: "of junk found")
                .foregroundStyle(.white)

            HStack(spacing: 40) {
                if case .results(let cleanup, _, _, _, _) = scanState {
                    resultPill(icon: "trash.circle", label: "Cleanup", value: FileSizeFormatter.format(cleanup))
                }
                if case .results(_, let threats, _, _, _) = scanState {
                    resultPill(icon: "shield.lefthalf.filled", label: "Protection", value: "\(threats) threats")
                }
                if case .results(_, _, let perf, _, _) = scanState {
                    resultPill(icon: "gauge.with.dots.needle.67percent", label: "Speed", value: "\(perf) items")
                }
            }

            Button("Clean") {
                runCleanup()
            }
            .buttonStyle(SuperEllipseButtonStyle(
                gradient: ModuleTheme.smartScan.gradient,
                size: CGSize(width: 160, height: 50)
            ))
        }
    }

    private func cleaningView(progress: Double) -> some View {
        VStack(spacing: 24) {
            ProgressGauge(progress: progress, label: "Cleaning", theme: .smartScan)
                .foregroundStyle(.white)

            Text("Cleaning your Mac...")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func doneView(freedSize: UInt64) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            SizeDisplay(size: freedSize, label: "freed up")
                .foregroundStyle(.white)

            Button("Done") {
                scanState = .idle
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }

    private func resultPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func startScan() {
        Task {
            scanState = .scanning(phase: "Analyzing system...", progress: 0, filesFound: 0, sizeFound: 0)

            appState.scanCoordinator.scanAll()

            // Poll the coordinator's state
            while true {
                try? await Task.sleep(for: .milliseconds(100))

                switch appState.scanCoordinator.state {
                case .scanning(let progress, let module, let files, let size):
                    scanState = .scanning(phase: module, progress: progress, filesFound: files, sizeFound: size)
                case .completed(let results):
                    let totalSize = results.reduce(0 as UInt64) { $0 + $1.totalSize }
                    scanState = .results(
                        cleanup: totalSize,
                        protection: 0,
                        performance: 0,
                        totalSize: totalSize,
                        moduleResults: results
                    )
                    return
                case .failed:
                    scanState = .idle
                    return
                case .idle:
                    continue
                }
            }
        }
    }

    private func runCleanup() {
        scanState = .cleaning(progress: 0)
        Task {
            try? await Task.sleep(for: .seconds(1))
            scanState = .done(freedSize: 0)
        }
    }
}
