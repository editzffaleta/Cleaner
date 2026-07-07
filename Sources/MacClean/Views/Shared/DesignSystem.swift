import SwiftUI
import MacCleanKit

// Design tokens do Cleaner (DESIGN_SYSTEM.md). Valores obrigatórios — não
// ajustar a olho. `Theme` é a paleta base; as extensões de `SidebarItem`
// trazem o accent/themeColor/ícone por módulo definidos na tabela §3.

enum Theme {
    static let accent   = Color(red: 0.49, green: 0.85, blue: 0.82) // teal claro — accent global
    static let bgTop    = Color(red: 0.055, green: 0.145, blue: 0.155)
    static let bgBottom = Color(red: 0.025, green: 0.075, blue: 0.085)
    static let sidebar  = Color(red: 0.035, green: 0.10, blue: 0.11)
    static let card     = Color(red: 0.075, green: 0.165, blue: 0.175)
    static let scanTop  = Color(red: 0.10, green: 0.47, blue: 0.49)
    static let scanBottom = Color(red: 0.03, green: 0.20, blue: 0.23)
}

extension SidebarItem {
    /// Cor de destaque do módulo (pill da sidebar, botões, toggles). Tabela §3.
    var dsAccent: Color {
        switch self {
        case .home, .smartScan, .settings, .cleanupHistory: Theme.accent
        case .systemJunk, .mailAttachments, .systemData: Color(red: 0.45, green: 0.85, blue: 0.60)
        case .trashBins: Color(white: 0.75)
        case .malwareRemoval: Color(red: 0.96, green: 0.48, blue: 0.48)
        case .privacy: Color(red: 0.98, green: 0.62, blue: 0.35)
        case .optimization, .maintenance: Color(red: 1.0, green: 0.75, blue: 0.32)
        case .uninstaller, .updater: Color(red: 0.74, green: 0.60, blue: 0.98)
        case .spaceLens, .largeOldFiles: Color(red: 0.38, green: 0.75, blue: 0.98)
        case .duplicates, .shredder: Color(red: 0.40, green: 0.85, blue: 0.85)
        }
    }

    /// Cor-base (escura) do gradiente de fundo da tela do módulo. Tabela §3.
    var dsThemeColor: Color {
        switch self {
        case .home, .settings, .cleanupHistory: Theme.bgTop
        case .smartScan: Theme.scanTop
        case .systemJunk, .systemData: Color(red: 0.06, green: 0.22, blue: 0.14)
        case .mailAttachments: Color(red: 0.05, green: 0.20, blue: 0.20)
        case .trashBins: Color(red: 0.13, green: 0.14, blue: 0.16)
        case .malwareRemoval: Color(red: 0.26, green: 0.09, blue: 0.10)
        case .privacy: Color(red: 0.28, green: 0.16, blue: 0.06)
        case .optimization: Color(red: 0.30, green: 0.22, blue: 0.06)
        case .maintenance: Color(red: 0.28, green: 0.20, blue: 0.05)
        case .uninstaller: Color(red: 0.18, green: 0.13, blue: 0.32)
        case .updater: Color(red: 0.16, green: 0.12, blue: 0.30)
        case .spaceLens: Color(red: 0.05, green: 0.18, blue: 0.28)
        case .largeOldFiles: Color(red: 0.07, green: 0.14, blue: 0.28)
        case .duplicates: Color(red: 0.05, green: 0.20, blue: 0.20)
        case .shredder: Color(red: 0.06, green: 0.17, blue: 0.22)
        }
    }

    /// Cor do ícone na sidebar quando NÃO selecionado.
    var dsIconColor: Color {
        switch self {
        case .home, .smartScan: Theme.accent
        case .systemJunk, .systemData: .green
        case .mailAttachments: .mint
        case .trashBins: .gray
        case .malwareRemoval: .red
        case .privacy: .orange
        case .optimization: .yellow
        case .maintenance: .orange
        case .uninstaller, .updater: .purple
        case .spaceLens: .cyan
        case .largeOldFiles: .blue
        case .duplicates: .teal
        case .shredder: .cyan
        case .settings, .cleanupHistory: .gray
        }
    }
}
