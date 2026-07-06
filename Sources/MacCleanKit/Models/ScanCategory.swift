import Foundation

public enum ScanCategory: String, CaseIterable, Identifiable, Sendable {
    // System Junk
    case userCaches = "user_caches"
    case systemCaches = "system_caches"
    case userLogs = "user_logs"
    case systemLogs = "system_logs"
    case languageFiles = "language_files"
    case brokenPreferences = "broken_preferences"
    case brokenLoginItems = "broken_login_items"
    case documentVersions = "document_versions"
    case brokenDownloads = "broken_downloads"
    case iosDeviceBackups = "ios_device_backups"
    case oldUpdates = "old_updates"
    case universalBinaries = "universal_binaries"
    case xcodeJunk = "xcode_junk"
    case deletedUsers = "deleted_users"
    case unusedDiskImages = "unused_disk_images"
    case incompleteDownloads = "incomplete_downloads"
    case appLeftovers = "app_leftovers"
    case packageManagerCaches = "package_manager_caches"
    case ideCaches = "ide_caches"
    case aiToolCaches = "ai_tool_caches"

    // Mail
    case mailAttachments = "mail_attachments"

    // Trash
    case trashBins = "trash_bins"

    // Protection
    case malware = "malware"
    case browserPrivacy = "browser_privacy"
    case systemPrivacy = "system_privacy"

    // Files
    case largeFiles = "large_files"
    case oldFiles = "old_files"
    case duplicates = "duplicates"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .userCaches: L10n.tr("用户缓存文件", "Arquivos de Cache do Usuário")
        case .systemCaches: L10n.tr("系统缓存文件", "Arquivos de Cache do Sistema")
        case .userLogs: L10n.tr("用户日志文件", "Arquivos de Log do Usuário")
        case .systemLogs: L10n.tr("系统日志文件", "Arquivos de Log do Sistema")
        case .languageFiles: L10n.tr("语言文件", "Arquivos de Idioma")
        case .brokenPreferences: L10n.tr("损坏的偏好设置", "Preferências Corrompidas")
        case .brokenLoginItems: L10n.tr("失效的登录项", "Itens de Início Quebrados")
        case .documentVersions: L10n.tr("文档版本", "Versões de Documentos")
        case .brokenDownloads: L10n.tr("残留下载文件", "Downloads Corrompidos")
        case .iosDeviceBackups: L10n.tr("iOS 设备备份", "Backups de Dispositivos iOS")
        case .oldUpdates: L10n.tr("旧更新文件", "Atualizações Antigas")
        case .universalBinaries: L10n.tr("通用二进制", "Binários Universais")
        case .xcodeJunk: L10n.tr("Xcode 垃圾", "Lixo do Xcode")
        case .deletedUsers: L10n.tr("已删除用户数据", "Usuários Excluídos")
        case .unusedDiskImages: L10n.tr("未使用的磁盘映像", "Imagens de Disco Não Usadas")
        case .incompleteDownloads: L10n.tr("未完成下载", "Downloads Incompletos")
        case .appLeftovers: L10n.tr("已删除应用的残留文件", "Resíduos de Apps Excluídos")
        case .packageManagerCaches: L10n.tr("包管理器缓存", "Caches de Gerenciadores de Pacotes")
        case .ideCaches: L10n.tr("IDE 与编辑器缓存", "Caches de IDEs e Editores")
        case .aiToolCaches: L10n.tr("AI 工具缓存", "Caches de Ferramentas de IA")
        case .mailAttachments: L10n.tr("邮件附件", "Anexos do Mail")
        case .trashBins: L10n.tr("废纸篓", "Lixeiras")
        case .malware: L10n.tr("恶意软件", "Malware")
        case .browserPrivacy: L10n.tr("浏览器隐私", "Privacidade do Navegador")
        case .systemPrivacy: L10n.tr("系统隐私", "Privacidade do Sistema")
        case .largeFiles: L10n.tr("大文件", "Arquivos Grandes")
        case .oldFiles: L10n.tr("旧文件", "Arquivos Antigos")
        case .duplicates: L10n.tr("重复文件", "Duplicatas")
        }
    }

    /// One-line description shown under the category name in the results list.
    public var subtitle: String {
        switch self {
        case .userCaches: L10n.tr("应用临时文件，下次启动会重新生成。", "Arquivos temporários do app. Recriados na próxima abertura.")
        case .systemCaches: L10n.tr("由 macOS 管理的缓存，会自动重建。", "Caches gerenciados pelo macOS. Recriados automaticamente.")
        case .userLogs: L10n.tr("应用写入的诊断日志。", "Logs de diagnóstico gravados pelos seus apps.")
        case .systemLogs: L10n.tr("macOS 诊断日志。", "Logs de diagnóstico do macOS.")
        case .languageFiles: L10n.tr("应用内未使用的本地化语言资源。", "Localizações não usadas incluídas nos apps.")
        case .brokenPreferences: L10n.tr("损坏或孤立的偏好设置文件。", "Arquivos de preferências corrompidos ou órfãos.")
        case .brokenLoginItems: L10n.tr("指向已不存在应用的登录项。", "Itens de início que apontam para apps que não existem mais.")
        case .documentVersions: L10n.tr("旧的自动保存文档版本。", "Revisões antigas de documentos salvos automaticamente.")
        case .brokenDownloads: L10n.tr("失败或孤立下载留下的文件。", "Resíduos de downloads falhos ou órfãos.")
        case .iosDeviceBackups: L10n.tr("iPhone 和 iPad 的本地备份。", "Backups locais de dispositivos iPhone e iPad.")
        case .oldUpdates: L10n.tr("更新后遗留的安装包。", "Pacotes de instalação deixados para trás após atualizações.")
        case .universalBinaries: L10n.tr("应用二进制中未使用的 CPU 架构切片。", "Fatias de CPU não usadas dentro dos binários dos apps.")
        case .xcodeJunk: L10n.tr("派生数据、归档和模拟器缓存。", "Dados derivados, arquivos e caches de simulador.")
        case .deletedUsers: L10n.tr("已移除用户账户留下的数据。", "Dados residuais de contas de usuário removidas.")
        case .unusedDiskImages: L10n.tr("曾经挂载但已不再需要的磁盘映像。", "Imagens de disco que você montou uma vez e esqueceu.")
        case .incompleteDownloads: L10n.tr("未下载完成的文件。", "Arquivos baixados parcialmente.")
        case .appLeftovers: L10n.tr("已删除应用留下的支持文件。", "Arquivos de suporte de apps que você excluiu.")
        case .packageManagerCaches: L10n.tr("npm、Cargo、pip、Homebrew、Gradle 的可重建缓存。", "Caches recriáveis do npm, Cargo, pip, Homebrew e Gradle.")
        case .ideCaches: L10n.tr("代码编辑器的缓存（Cursor、Antigravity 等）。", "Caches de editores de código como Cursor e Antigravity.")
        case .aiToolCaches: L10n.tr("AI 编码工具的缓存（Claude、Codex）；不含历史与会话。", "Caches de ferramentas de programação com IA (Claude, Codex). Histórico e sessões são excluídos.")
        case .mailAttachments: L10n.tr("邮件附件的缓存副本。", "Cópias salvas de anexos do Mail.")
        case .trashBins: L10n.tr("当前位于废纸篓中的项目。", "Itens que estão atualmente na Lixeira.")
        case .malware: L10n.tr("在磁盘上发现的已知恶意文件。", "Arquivos maliciosos conhecidos encontrados no disco.")
        case .browserPrivacy: L10n.tr("浏览历史和跟踪数据；Cookie 与会话会保留。", "Histórico de navegação e dados de rastreamento. Cookies e sessões são mantidos.")
        case .systemPrivacy: L10n.tr("最近项目列表和其他隐私痕迹。", "Listas de itens recentes e outros rastros de privacidade.")
        case .largeFiles: L10n.tr("占用空间最多的文件。", "Os arquivos que ocupam mais espaço.")
        case .oldFiles: L10n.tr("长时间未打开的文件。", "Arquivos que você não abre há muito tempo.")
        case .duplicates: L10n.tr("同一文件的相同副本。", "Cópias idênticas do mesmo arquivo.")
        }
    }

    public var systemImage: String {
        switch self {
        case .userCaches, .systemCaches: "folder.badge.gearshape"
        case .userLogs, .systemLogs: "doc.text"
        case .languageFiles: "globe"
        case .brokenPreferences: "gearshape.triangle.fill"
        case .brokenLoginItems: "person.crop.circle.badge.exclamationmark"
        case .documentVersions: "doc.on.doc"
        case .brokenDownloads, .incompleteDownloads: "arrow.down.circle.dotted"
        case .iosDeviceBackups: "iphone"
        case .oldUpdates: "arrow.triangle.2.circlepath"
        case .universalBinaries: "cpu"
        case .xcodeJunk: "hammer"
        case .deletedUsers: "person.crop.circle.badge.minus"
        case .unusedDiskImages: "opticaldisc"
        case .appLeftovers: "shippingbox.and.arrow.backward"
        case .packageManagerCaches: "shippingbox"
        case .ideCaches: "macwindow"
        case .aiToolCaches: "sparkles"
        case .mailAttachments: "paperclip"
        case .trashBins: "trash"
        case .malware: "shield.lefthalf.filled.trianglebadge.exclamationmark"
        case .browserPrivacy: "safari"
        case .systemPrivacy: "hand.raised"
        case .largeFiles: "arrow.up.right.square"
        case .oldFiles: "clock.arrow.circlepath"
        case .duplicates: "plus.square.on.square"
        }
    }

    public var autoSelect: Bool {
        switch self {
        case .unusedDiskImages, .largeFiles, .oldFiles, .duplicates,
             .universalBinaries, .appLeftovers,
             .packageManagerCaches, .ideCaches, .aiToolCaches:
            // appLeftovers: deletes another app's leftover data; detection is
            // conservative but never auto-checked — the user reviews first.
            // universalBinaries: thinning rewrites the app's binaries in
            // place (lipo preserves their signatures; we never re-sign).
            // Still only reversible by re-downloading the app, so don't
            // pre-check — force explicit consent.
            false
        default:
            true
        }
    }
}
