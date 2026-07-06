import SwiftUI
import AppKit
import MacCleanKit

@main
struct MacCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("showMenuBarWidget") private var showMenuBarWidget = true
    @AppStorage("menuBarFirstLaunchDone") private var menuBarFirstLaunchDone = false
    @AppStorage(AppLanguage.defaultsKey, store: SharedAppState.defaults) private var appLanguageRaw = AppLanguage.system.rawValue
    @State private var showOnboarding = false

    init() {
        AppLanguage.registerDefault(.system)
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRaw) ?? .fallback
    }

    var body: some Scene {
        // A single Window (not WindowGroup) so reopening the app, or following
        // a macclean:// deeplink from the menu bar while a window already
        // exists, reuses the one window instead of spawning a second. Combined
        // with LSMultipleInstancesProhibited in Info.plist (which keeps macOS
        // from launching a second process), the user never ends up with two
        // copies of the main window.
        Window(MCConstants.appName, id: "main") {
            ContentView()
                .environment(appState)
                .tint(Color.brand)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                .id(appLanguage.rawValue)
                .frame(minWidth: 1180, minHeight: 720)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .tint(Color.brand)
                        .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
                        .id(appLanguage.rawValue)
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                        hasCompletedOnboarding = true
                    }
                    syncMenuBarOnLaunch()
                }
                .onOpenURL { url in
                    // Two shapes: macclean://module/<slug> navigates; and
                    // macclean://action/<name> runs a one-tap action from the
                    // menu-bar widget. Both have exactly one path segment
                    // (pathComponents is ["/", "<value>"]).
                    guard url.scheme == "macclean", url.pathComponents.count == 2,
                          let value = url.pathComponents.last else { return }
                    switch url.host {
                    case "module":
                        if let item = SidebarItem(deepLinkID: value) {
                            appState.selectedSidebarItem = item
                        }
                    case "action":
                        handleWidgetAction(value)
                    default:
                        break
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 772)
        // Keep the standard "Settings…" menu item + Cmd-comma, but route
        // them to the in-app page (the separate Settings window is gone).
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.tr("设置…", "Ajustes…")) {
                    appState.selectedSidebarItem = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    /// First-launch default: ON (per product decision). On every launch
    /// we re-sync the SMAppService state with the preference so the
    /// truth of "is the helper actually running" matches the toggle —
    /// macOS occasionally drops registrations after updates, especially
    /// when the helper bundle path changes (which it doesn't here, but
    /// re-registering is cheap and idempotent).
    /// One-tap actions sent by the menu-bar widget as macclean://action/<name>.
    @MainActor
    private func handleWidgetAction(_ name: String) {
        switch name {
        case "quick-clean":
            // Show the history (which updates live) and run a safe clean now.
            appState.selectedSidebarItem = .cleanupHistory
            let engine = appState.cleaningEngine
            Task { await ScheduledCleanupRunner.perform(engine: engine, source: CleanHistorySource.widget) }
        default:
            break
        }
    }

    private func syncMenuBarOnLaunch() {
        if !menuBarFirstLaunchDone {
            menuBarFirstLaunchDone = true
            // showMenuBarWidget already defaults to true; setEnabled is
            // idempotent if already registered.
        }
        // Async: the SMAppService XPC round-trip must not block app launch.
        Task { await MenuBarLauncher.shared.setEnabled(showMenuBarWidget) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceManager.applyStored()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
