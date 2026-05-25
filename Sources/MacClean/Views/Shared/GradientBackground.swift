import SwiftUI

public enum ModuleTheme {
    case smartScan
    case cleanup
    case protection
    case performance
    case applications
    case files

    public var gradient: LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public var colors: [Color] {
        switch self {
        case .smartScan:
            [Color(red: 0.35, green: 0.30, blue: 0.85), Color(red: 0.55, green: 0.35, blue: 0.95)]
        case .cleanup:
            [Color(red: 0.18, green: 0.70, blue: 0.45), Color(red: 0.25, green: 0.82, blue: 0.55)]
        case .protection:
            [Color(red: 0.90, green: 0.30, blue: 0.25), Color(red: 0.95, green: 0.45, blue: 0.30)]
        case .performance:
            [Color(red: 0.95, green: 0.70, blue: 0.20), Color(red: 0.98, green: 0.80, blue: 0.30)]
        case .applications:
            [Color(red: 0.65, green: 0.30, blue: 0.85), Color(red: 0.80, green: 0.40, blue: 0.90)]
        case .files:
            [Color(red: 0.15, green: 0.65, blue: 0.80), Color(red: 0.20, green: 0.78, blue: 0.88)]
        }
    }

    public var accentColor: Color {
        colors[0]
    }
}

public struct GradientBackgroundView: View {
    let theme: ModuleTheme

    public init(theme: ModuleTheme) {
        self.theme = theme
    }

    public var body: some View {
        ZStack {
            theme.gradient
                .ignoresSafeArea()

            // Subtle radial glow
            RadialGradient(
                colors: [.white.opacity(0.1), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }
}
