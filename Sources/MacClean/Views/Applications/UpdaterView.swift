import SwiftUI
import MacCleanKit

struct UpdaterView: View {
    @State private var updates: [AppUpdateChecker.AppUpdate] = []
    @State private var isChecking = false
    @State private var apps: [AppInfo] = []

    private let discovery = AppDiscovery()
    private let checker = AppUpdateChecker()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Updater")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Check for available app updates")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button(isChecking ? "Checking..." : "Check for Updates") {
                    checkUpdates()
                }
                .buttonStyle(SuperEllipseButtonStyle(
                    gradient: ModuleTheme.applications.gradient,
                    size: CGSize(width: 180, height: 36)
                ))
                .disabled(isChecking)
            }
            .padding(20)

            if isChecking {
                Spacer()
                ProgressView("Checking for updates...")
                    .foregroundStyle(.white)
                    .tint(.white)
                Spacer()
            } else if updates.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("All apps are up to date")
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            } else {
                List {
                    ForEach(updates) { update in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.app.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text("\(update.currentVersion) → \(update.availableVersion ?? "?")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Update") {}
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
                .listStyle(.inset)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func checkUpdates() {
        isChecking = true
        Task {
            apps = await discovery.discoverApps()
            updates = await checker.checkForUpdates(apps: apps)
            isChecking = false
        }
    }
}
