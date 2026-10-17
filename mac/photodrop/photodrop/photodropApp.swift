import SwiftUI

@main
struct PhotoDropApp: App {
    @StateObject private var viewModel = PhotoSpaceViewModel()

    var body: some Scene {
        Window("PhotoDrop", id: "canvas") {
            ContentView(viewModel: viewModel)
                .task { viewModel.start() }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandMenu("PhotoDrop") {
                Button("Reconnect") { viewModel.start() }
                Button("Disconnect") { viewModel.websocket.disconnect() }
                Divider()
                Button("Test Screenshot…") { viewModel.testScreenshot() }
                Button("Add Test Clip") { viewModel.addTestClip() }
                Button("Clear Clips") { viewModel.clips.removeAll() }
                    .keyboardShortcut(.delete, modifiers: [.command])
            }
        }

        Settings { SettingsView(viewModel: viewModel) }
    }
}
