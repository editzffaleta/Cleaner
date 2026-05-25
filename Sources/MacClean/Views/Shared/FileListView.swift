import SwiftUI
import MacCleanKit

public struct FileListView: View {
    let results: [ScanResult]
    @Binding var selectedItems: Set<URL>

    public init(results: [ScanResult], selectedItems: Binding<Set<URL>>) {
        self.results = results
        self._selectedItems = selectedItems
    }

    public var body: some View {
        List {
            ForEach(results, id: \.category) { result in
                Section {
                    ForEach(result.items) { item in
                        FileRowView(
                            item: item,
                            isSelected: selectedItems.contains(item.url),
                            onToggle: {
                                if selectedItems.contains(item.url) {
                                    selectedItems.remove(item.url)
                                } else {
                                    selectedItems.insert(item.url)
                                }
                            }
                        )
                    }
                } header: {
                    CategoryHeaderView(
                        category: result.category,
                        totalSize: result.totalSize,
                        fileCount: result.fileCount,
                        allSelected: result.items.allSatisfy { selectedItems.contains($0.url) },
                        onToggleAll: {
                            let urls = Set(result.items.map(\.url))
                            if urls.isSubset(of: selectedItems) {
                                selectedItems.subtract(urls)
                            } else {
                                selectedItems.formUnion(urls)
                            }
                        }
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct CategoryHeaderView: View {
    let category: ScanCategory
    let totalSize: UInt64
    let fileCount: Int
    let allSelected: Bool
    let onToggleAll: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(get: { allSelected }, set: { _ in onToggleAll() })) {
                HStack(spacing: 8) {
                    Image(systemName: category.systemImage)
                        .foregroundStyle(.secondary)
                    Text(category.displayName)
                        .font(.headline)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            Text("\(fileCount) files")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(FileSizeFormatter.format(totalSize))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
        }
    }
}

struct FileRowView: View {
    let item: FileItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()

            Image(systemName: item.isDirectory ? "folder.fill" : fileIcon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer()

            Text(item.formattedSize)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var fileIcon: String {
        switch item.fileExtension {
        case "log", "txt": "doc.text"
        case "plist", "json", "xml": "doc.badge.gearshape"
        case "cache", "db", "sqlite": "cylinder"
        case "dmg": "opticaldisc"
        case "zip", "gz", "tar": "doc.zipper"
        case "lproj": "globe"
        default: "doc"
        }
    }
}
