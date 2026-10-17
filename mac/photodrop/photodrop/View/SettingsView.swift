import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PhotoSpaceViewModel
    @ObservedObject private var websocket: Websocket
    @State private var screens: [NSScreen] = []
    @State private var hasPermission = CGPreflightScreenCaptureAccess()

    init(viewModel: PhotoSpaceViewModel) {
        self.viewModel = viewModel
        websocket = viewModel.websocket
    }

    var body: some View {
        Form {
            Section("Server") {
                TextField("API URL", text: $viewModel.serverURL)
                    .autocorrectionDisabled()
                Text("Use the same API server as the phone. Local default: http://localhost:8000")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Connect") { viewModel.start() }.keyboardShortcut(.defaultAction)
                    Button("Disconnect") { websocket.disconnect() }
                    Spacer()
                    Text(websocket.status).font(.caption)
                }
                if let error = websocket.lastError {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
            }

            Section("Display") {
                Picker("Photographed display", selection: $viewModel.selectedDisplayID) {
                    Text("Automatic (original behavior)").tag(UInt32(0))
                    ForEach(screens, id: \.self) { screen in
                        Text(screen.localizedName).tag(ScreenCapture.displayID(for: screen))
                    }
                }
                .onChange(of: viewModel.selectedDisplayID) { _, value in
                    UserDefaults.standard.set(Int(value), forKey: "selectedDisplayID")
                }
                Text("Point the phone at this display. Expand or move the transparent canvas over the area where clips should appear. Clips are centered at the aiming point and displayed 150 points wide.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Screen Recording") {
                Label(hasPermission ? "Permission granted" : "Permission required",
                      systemImage: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle")
                HStack {
                    Button("Request Permission") {
                        _ = CGRequestScreenCaptureAccess()
                        hasPermission = CGPreflightScreenCaptureAccess()
                    }
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Text("After granting access, quit and reopen PhotoDrop. Screenshots are sent to the configured server only when a phone trigger arrives.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Test Screenshot…") { viewModel.testScreenshot() }
            }

            Section("Canvas") {
                HStack {
                    Button("Add Test Clip") { viewModel.addTestClip() }
                    Button("Clear Clips") { viewModel.clips.removeAll() }
                    Spacer()
                    Text("\(viewModel.clips.count) clips").foregroundStyle(.secondary)
                }
                if let error = viewModel.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 570, height: 690)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in refresh() }
    }

    private func refresh() {
        screens = NSScreen.screens
        hasPermission = CGPreflightScreenCaptureAccess()
    }
}
