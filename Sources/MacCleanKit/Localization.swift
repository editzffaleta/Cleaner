import Foundation

/// User-facing language for the Mac Sai interface.
///
/// We keep the preference in the shared defaults suite so the main app and the
/// menu-bar helper switch languages together.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public static let defaultsKey = "appLanguage"
    public static let fallback: AppLanguage = .en

    public var id: String { rawValue }

    public var localeIdentifier: String { resolved.localeIdentifierForResolvedLanguage }

    private var localeIdentifierForResolvedLanguage: String {
        switch self {
        case .system:
            Self.systemPreferred.localeIdentifierForResolvedLanguage
        case .zhHans:
            "zh-Hans"
        case .en:
            "en"
        }
    }

    public var resolved: AppLanguage {
        switch self {
        case .system: Self.systemPreferred
        case .zhHans, .en: self
        }
    }

    public static var systemPreferred: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        let normalized = preferred.replacingOccurrences(of: "_", with: "-").lowercased()
        return normalized.hasPrefix("zh") ? .zhHans : .en
    }

    /// Label shown in the language picker. These are intentionally native names
    /// instead of going through `L10n.tr`, so users can always find their
    /// preferred language even if the current UI language is unfamiliar.
    public var pickerLabel: String {
        switch self {
        case .system: L10n.tr("跟随系统", "Sistema")
        case .zhHans: "简体中文"
        case .en: "Português (Brasil)"
        }
    }

    public static var current: AppLanguage {
        get {
            if let raw = SharedAppState.defaults.string(forKey: defaultsKey),
               let language = AppLanguage(rawValue: raw) {
                return language
            }
            if let raw = UserDefaults.standard.string(forKey: defaultsKey),
               let language = AppLanguage(rawValue: raw) {
                return language
            }
            return fallback
        }
        set {
            SharedAppState.defaults.set(newValue.rawValue, forKey: defaultsKey)
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    /// Set a product default without changing an existing user choice. Tests and
    /// command-line tools keep the English fallback, while the shipped apps call
    /// this on launch to follow the user's system language by default.
    public static func registerDefault(_ language: AppLanguage) {
        guard SharedAppState.defaults.string(forKey: defaultsKey) == nil,
              UserDefaults.standard.string(forKey: defaultsKey) == nil else { return }
        current = language
    }
}

/// Lightweight runtime localization used by both executables.
///
/// The project is mostly SwiftUI views plus model strings that were originally
/// hard-coded. A full `.strings` migration would require touching almost every
/// call site and packaging resource bundles for the custom app builder. This
/// helper keeps the current no-resource build flow while still allowing instant
/// Chinese/English switching at runtime.
public enum L10n {
    public static func tr(_ zhHans: String, _ english: @autoclosure () -> String) -> String {
        AppLanguage.current.resolved == .en ? english() : zhHans
    }

    public static func tr(_ zhHans: String) -> String {
        guard AppLanguage.current.resolved == .en else { return zhHans }
        return englishFallbacks[zhHans] ?? zhHans
    }

    /// Small fallback table for values that are assembled dynamically or flow
    /// through model properties. Most UI strings use the two-argument overload
    /// so the original English expression can live beside the Chinese text.
    private static let englishFallbacks: [String: String] = [
        "智能扫描": "Escaneamento Inteligente",
        "系统垃圾": "Lixo do Sistema",
        "邮件附件": "Anexos do Mail",
        "废纸篓": "Lixeiras",
        "恶意软件清理": "Remoção de Malware",
        "隐私清理": "Privacidade",
        "优化": "Otimização",
        "维护": "Manutenção",
        "卸载器": "Desinstalador",
        "应用更新": "Atualizador",
        "空间透视": "Lente de Espaço",
        "大文件与旧文件": "Arquivos Grandes e Antigos",
        "重复文件": "Duplicatas",
        "文件粉碎": "Triturador",
        "设置": "Ajustes",
        "清理历史": "Histórico de Limpezas",
        "清理": "Limpeza",
        "防护": "Proteção",
        "性能": "Desempenho",
        "应用": "Aplicativos",
        "文件": "Arquivos",
        "全部": "Todos",
        "未使用": "Não usado",
        "第三方": "Terceiros",
        "快速": "Rápido",
        "平衡": "Balanceado",
        "深度": "Profundo",
        "开启": "ativar",
        "关闭": "desativar",
        "压缩包": "Arquivos compactados",
        "已选择": "Selecionado",
        "运行中": "Em execução",
        "未知": "Desconhecido",
        "进度": "Progresso",
        "释放内存": "Liberar RAM",
        "释放可清除空间": "Liberar Espaço Purgável",
        "运行维护脚本": "Executar Scripts de Manutenção",
        "验证启动磁盘": "Verificar Disco de Inicialização",
        "加速邮件": "Acelerar o Mail",
        "重建启动服务": "Reconstruir Launch Services",
        "重建 Spotlight 索引": "Reindexar o Spotlight",
        "刷新 DNS 缓存": "Limpar Cache DNS",
        "精简 Time Machine 快照": "Reduzir Snapshots do Time Machine",
    ]
}
