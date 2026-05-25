import SwiftUI
import MacCleanKit

struct SpaceLensView: View {
    @State private var rootNode: FileNode?
    @State private var treemapRects: [TreemapRect] = []
    @State private var isScanning = false
    @State private var breadcrumbs: [URL] = []
    @State private var currentURL: URL = MCConstants.home
    @State private var selectedVolume: URL = URL(filePath: "/")

    private let scanner = FileTreeScanner()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Space Lens")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Visualize disk space usage")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if !isScanning {
                    Button("Scan") { startScan() }
                        .buttonStyle(SuperEllipseButtonStyle(
                            gradient: ModuleTheme.files.gradient,
                            size: CGSize(width: 100, height: 36)
                        ))
                }
            }
            .padding(20)

            // Breadcrumb navigation
            if !breadcrumbs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(breadcrumbs, id: \.self) { url in
                            Button(url.lastPathComponent) {
                                navigateTo(url)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.system(size: 12))

                            if url != breadcrumbs.last {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }

            // Treemap
            if isScanning {
                Spacer()
                ProgressView("Scanning disk...")
                    .foregroundStyle(.white)
                    .tint(.white)
                Spacer()
            } else if !treemapRects.isEmpty {
                GeometryReader { geo in
                    ZStack {
                        ForEach(treemapRects) { item in
                            treemapCell(item, containerSize: geo.size)
                        }
                    }
                    .padding(20)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Click Scan to visualize disk usage")
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
        }
    }

    private func treemapCell(_ item: TreemapRect, containerSize: CGSize) -> some View {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint]
        let colorIndex = abs(item.node.name.hashValue) % colors.count

        return RoundedRectangle(cornerRadius: 4)
            .fill(colors[colorIndex].opacity(0.7))
            .frame(width: max(item.rect.width - 2, 0), height: max(item.rect.height - 2, 0))
            .overlay {
                if item.rect.width > 60 && item.rect.height > 30 {
                    VStack(spacing: 2) {
                        Text(item.node.name)
                            .font(.system(size: max(9, min(13, item.rect.width / 10))))
                            .lineLimit(1)
                        Text(item.node.formattedSize)
                            .font(.system(size: max(8, min(10, item.rect.width / 12))))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(4)
                }
            }
            .position(x: item.rect.midX, y: item.rect.midY)
            .onTapGesture {
                if item.node.isDirectory {
                    breadcrumbs.append(item.node.url)
                    currentURL = item.node.url
                    startScan()
                }
            }
    }

    private func startScan() {
        isScanning = true
        if breadcrumbs.isEmpty {
            breadcrumbs = [currentURL]
        }
        Task {
            let node = await scanner.scanWithSizeAggregation(root: currentURL)
            rootNode = node

            let treemapNodes = node.children
                .sorted { $0.totalSize > $1.totalSize }
                .prefix(50) // Top 50 for performance
                .map { child in
                    TreemapNode(
                        name: child.name,
                        size: child.totalSize,
                        url: child.url,
                        isDirectory: child.isDirectory,
                        children: []
                    )
                }

            let bounds = CGRect(x: 0, y: 0, width: 700, height: 400)
            treemapRects = SquarifiedTreemap.layout(nodes: Array(treemapNodes), in: bounds)
            isScanning = false
        }
    }

    private func navigateTo(_ url: URL) {
        if let index = breadcrumbs.firstIndex(of: url) {
            breadcrumbs = Array(breadcrumbs.prefix(through: index))
            currentURL = url
            startScan()
        }
    }
}
