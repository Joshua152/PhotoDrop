import AppKit
import ScreenCaptureKit

@MainActor
enum ScreenCapture {
    struct Result {
        let jpegData: Data
        let pngData: Data
        let displayFrame: CGRect
    }

    static func takeScreenshot(displayID: UInt32 = 0) async throws -> Result {
        guard CGPreflightScreenCaptureAccess() else {
            throw PhotoDropError.message("Allow PhotoDrop in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen PhotoDrop.")
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        // Automatic preserves the original client's choice: the smallest display ID.
        let display = displayID == 0
            ? content.displays.min(by: { $0.displayID < $1.displayID })
            : content.displays.first(where: { $0.displayID == displayID })
        guard let display, let screen = NSScreen.screens.first(where: { self.displayID(for: $0) == display.displayID }) else {
            throw PhotoDropError.message("The selected display is unavailable. Choose a display in PhotoDrop Settings.")
        }
        let displayFrame = screen.frame
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        // Match the full display without padding. The API normalizes to this image.
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw PhotoDropError.message("Could not encode the screenshot.")
        }
        return Result(jpegData: jpeg, pngData: png, displayFrame: displayFrame)
    }

    static func displayID(for screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
