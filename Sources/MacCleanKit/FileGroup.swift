import Foundation

/// Groups a list of `FileItem` values for display. Pure logic.
public enum FileGroup: Sendable {
    case byType
    case bySize
    case byAge

    public func group(_ items: [FileItem], now: Date = Date()) -> [(String, [FileItem])] {
        switch self {
        case .byType: Self.groupByType(items)
        case .bySize: Self.groupBySize(items)
        case .byAge: Self.groupByAge(items, now: now)
        }
    }

    static func groupByType(_ items: [FileItem]) -> [(String, [FileItem])] {
        var groups: [String: [FileItem]] = [:]
        for item in items {
            let type = fileTypeLabel(item.fileExtension)
            groups[type, default: []].append(item)
        }
        return groups.sorted { $0.key < $1.key }
    }

    static func groupBySize(_ items: [FileItem]) -> [(String, [FileItem])] {
        var groups: [String: [FileItem]] = [
            "1 GB+": [],
            "500 MB - 1 GB": [],
            "100 - 500 MB": [],
            "50 - 100 MB": [],
        ]
        for item in items {
            let mb = item.size / (1024 * 1024)
            if mb >= 1024 {
                groups["1 GB+", default: []].append(item)
            } else if mb >= 500 {
                groups["500 MB - 1 GB", default: []].append(item)
            } else if mb >= 100 {
                groups["100 - 500 MB", default: []].append(item)
            } else {
                groups["50 - 100 MB", default: []].append(item)
            }
        }
        return groups.filter { !$0.value.isEmpty }.sorted { $0.key > $1.key }
    }

    static func groupByAge(_ items: [FileItem], now: Date) -> [(String, [FileItem])] {
        var groups: [String: [FileItem]] = [:]
        for item in items {
            guard let modDate = item.modificationDate else { continue }
            let days = Int(now.timeIntervalSince(modDate) / (24 * 3600))
            let label = ageLabel(days: days)
            groups[label, default: []].append(item)
        }
        return groups.sorted { $0.key > $1.key }
    }

    public static func ageLabel(days: Int) -> String {
        if days > 365 { return L10n.tr("超过 1 年", "Mais de 1 ano") }
        if days > 180 { return L10n.tr("6 个月 - 1 年", "6 meses - 1 ano") }
        if days > 90 { return L10n.tr("3 - 6 个月", "3 - 6 meses") }
        if days > 30 { return L10n.tr("1 - 3 个月", "1 - 3 meses") }
        return L10n.tr("最近 1 个月", "Mês passado")
    }

    public static func fileTypeLabel(_ ext: String) -> String {
        switch ext {
        case "mp4", "mov", "avi", "mkv", "wmv", "flv": L10n.tr("视频", "Vídeos")
        case "mp3", "wav", "flac", "aac", "m4a", "ogg": L10n.tr("音频", "Áudio")
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp", "raw": L10n.tr("图片", "Imagens")
        case "pdf": L10n.tr("PDF", "PDFs")
        case "doc", "docx", "pages", "rtf", "txt": L10n.tr("文档", "Documentos")
        case "xls", "xlsx", "numbers", "csv": L10n.tr("表格", "Planilhas")
        case "zip", "gz", "tar", "rar", "7z", "bz2": L10n.tr("压缩包")
        case "dmg", "iso", "img": L10n.tr("磁盘映像", "Imagens de Disco")
        case "app": L10n.tr("应用程序", "Aplicativos")
        case "pkg", "mpkg": L10n.tr("安装包", "Instaladores")
        default: L10n.tr("其他", "Outros")
        }
    }
}
