import SwiftUI

@main
struct MacCleanApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 800, minHeight: 550)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 960, height: 620)
    }
}
