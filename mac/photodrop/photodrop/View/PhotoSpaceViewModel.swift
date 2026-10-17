//
//  PhotoSpaceViewModel.swift
//  PhotoDrop
//

import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
class PhotoSpaceViewModel: ObservableObject {
    struct Clip {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let image: NSImage
    }

    @Published var clips: [Clip] = []
    @Published var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:8000"
    @Published var selectedDisplayID = UInt32(UserDefaults.standard.integer(forKey: "selectedDisplayID"))
    @Published var errorMessage: String?

    // The background view shares the SwiftUI canvas's bounds and lifetime.
    weak var canvasView: NSView?
    let websocket = Websocket()

    init() {
        websocket.onClipReceive = { [weak self] clip, displayFrame in
            self?.onClipReceive(networkClip: clip, capturedDisplayFrame: displayFrame)
        }
        websocket.capture = { [weak self] in
            try await ScreenCapture.takeScreenshot(displayID: self?.selectedDisplayID ?? 0)
        }
    }

    func start() {
        // Unit tests and previews never open a real socket.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        do {
            let endpoint = try APIEndpoint(serverURL)
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            UserDefaults.standard.set(Int(selectedDisplayID), forKey: "selectedDisplayID")
            websocket.connect(to: endpoint)
        } catch { errorMessage = error.localizedDescription }
    }

    func addTestClip() {
        guard let canvas = canvasView,
              let image = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: "Test clip") else { return }
        clips.append(Clip(x: canvas.bounds.width / 2, y: canvas.bounds.height / 2, image: image))
    }

    func testScreenshot() {
        Task {
            do {
                let capture = try await ScreenCapture.takeScreenshot(displayID: selectedDisplayID)
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]
                panel.nameFieldStringValue = "PhotoDrop-screenshot.png"
                panel.message = "Save the exact display image used for placement."
                guard await panel.begin() == .OK, let url = panel.url else { return }
                try capture.pngData.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch { errorMessage = error.localizedDescription }
        }
    }

    func onClipReceive(networkClip: NetworkClip, capturedDisplayFrame: CGRect) {
        guard let point = Self.screenPercentToCanvasCoordinates(
            xPercent: networkClip.x,
            yPercent: networkClip.y,
            capturedDisplayFrame: capturedDisplayFrame,
            canvasView: canvasView
        ) else {
            errorMessage = "Cannot place the clip because the canvas is unavailable or the coordinates are invalid."
            return
        }

        guard let image = decodeBase64ToImage(base64Image: networkClip.clip) else {
            errorMessage = "The received clip is not a valid image."
            return
        }

        // The API returns the aiming point; .position places the clip's center there.
        clips.append(Clip(
            x: point.x,
            y: point.y,
            image: image
        ))
    }

    /// Returns points relative to the SwiftUI canvas's top-left.
    /// The API coordinates are fractions of a full-display screenshot.
    static func screenPercentToCanvasCoordinates(
        xPercent: Double,
        yPercent: Double,
        capturedDisplayFrame: CGRect,
        canvasView: NSView?
    ) -> CGPoint? {
        guard xPercent.isFinite, yPercent.isFinite,
              capturedDisplayFrame.minX.isFinite, capturedDisplayFrame.minY.isFinite,
              capturedDisplayFrame.width.isFinite, capturedDisplayFrame.height.isFinite,
              capturedDisplayFrame.width > 0, capturedDisplayFrame.height > 0,
              let canvas = canvasView, let window = canvas.window,
              canvas.bounds.width > 0, canvas.bounds.height > 0 else {
            return nil
        }

        // Screenshot y points down; global AppKit y points up.
        let screenPoint = CGPoint(
            x: capturedDisplayFrame.minX + CGFloat(xPercent) * capturedDisplayFrame.width,
            y: capturedDisplayFrame.maxY - CGFloat(yPercent) * capturedDisplayFrame.height
        )
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let localPoint = canvas.convert(windowPoint, from: nil)

        // Normalize either AppKit view orientation to SwiftUI's top-left origin.
        return CGPoint(
            x: localPoint.x - canvas.bounds.minX,
            y: canvas.isFlipped
                ? localPoint.y - canvas.bounds.minY
                : canvas.bounds.maxY - localPoint.y
        )
    }
}
