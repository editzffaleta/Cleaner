import SwiftUI
import MacCleanKit

struct ModuleContainerView: View {
    let title: String
    let subtitle: String
    let theme: ModuleTheme
    let results: [ScanResult]
    @Binding var selectedItems: Set<URL>
    let isScanning: Bool
    let isDone: Bool
    let freedSize: UInt64
    let onScan: () -> Void
    let onClean: () -> Void
    let onReset: () -> Void

    private var totalSelected: UInt64 {
        results.flatMap(\.items)
            .filter { selectedItems.contains($0.url) }
            .reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isDone {
                doneView
            } else if !results.isEmpty {
                resultsView
            } else if isScanning {
                scanningView
            } else {
                idleView
            }
        }
        .padding(20)
    }

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            ScanButton(title: "Scan", subtitle: title, theme: theme, action: onScan)
            Spacer()
        }
    }

    private var scanningView: some View {
        VStack(spacing: 32) {
            Spacer()
            ScanButton(title: "Scan", theme: theme, isScanning: true, progress: 0.5, action: {})
            Text("Scanning...")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            HStack {
                SizeDisplay(size: totalSelected, label: "selected")
                    .foregroundStyle(.white)
                Spacer()
                Button("Clean") { onClean() }
                    .buttonStyle(SuperEllipseButtonStyle(
                        gradient: theme.gradient,
                        size: CGSize(width: 120, height: 44)
                    ))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            FileListView(results: results, selectedItems: $selectedItems)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
            SizeDisplay(size: freedSize, label: "cleaned up")
                .foregroundStyle(.white)
            Button("Done") { onReset() }
                .buttonStyle(.bordered)
                .tint(.white)
            Spacer()
        }
    }
}
