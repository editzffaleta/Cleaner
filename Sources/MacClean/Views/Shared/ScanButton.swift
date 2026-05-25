import SwiftUI

public struct ScanButton: View {
    let title: String
    let subtitle: String?
    let theme: ModuleTheme
    let isScanning: Bool
    let progress: Double
    let action: () -> Void

    public init(
        title: String = "Scan",
        subtitle: String? = nil,
        theme: ModuleTheme = .smartScan,
        isScanning: Bool = false,
        progress: Double = 0,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.isScanning = isScanning
        self.progress = progress
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if isScanning {
                    scanningView
                } else {
                    idleView
                }
            }
        }
        .buttonStyle(SuperEllipseButtonStyle(
            gradient: theme.gradient,
            size: CGSize(width: 200, height: 200)
        ))
        .disabled(isScanning)
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
            Text(title)
                .font(.system(size: 22, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .opacity(0.8)
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }

            Text("Scanning...")
                .font(.system(size: 14, weight: .medium))
        }
    }
}
