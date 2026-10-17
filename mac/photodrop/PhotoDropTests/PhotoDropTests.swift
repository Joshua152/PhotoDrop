import XCTest
import AppKit
@testable import PhotoDrop

final class PhotoDropTests: XCTestCase {
    private class FlippedCanvas: NSView {
        override var isFlipped: Bool { true }
    }

    @MainActor
    func testProjectionIntoInsetCanvasWithBothAxisOrientations() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 150, y: 180, width: 700, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let content = try XCTUnwrap(window.contentView)

        for canvas in [NSView(), FlippedCanvas()] {
            canvas.frame = NSRect(x: 30, y: 40, width: 400, height: 300)
            content.addSubview(canvas)

            // A known point 80 right and 60 down from the canvas's top-left.
            let expectedLocal = CGPoint(x: 80, y: canvas.isFlipped ? 60 : 240)
            let global = window.convertPoint(toScreen: canvas.convert(expectedLocal, to: nil))

            // Include displays with nonzero and negative desktop origins.
            for display in [
                CGRect(x: 0, y: 0, width: 1600, height: 1000),
                CGRect(x: -1600, y: 200, width: 1600, height: 1000)
            ] {
                let result = try XCTUnwrap(PhotoSpaceViewModel.screenPercentToCanvasCoordinates(
                    xPercent: (global.x - display.minX) / display.width,
                    yPercent: (display.maxY - global.y) / display.height,
                    capturedDisplayFrame: display,
                    canvasView: canvas
                ))
                XCTAssertEqual(result.x, 80, accuracy: 0.0001)
                XCTAssertEqual(result.y, 60, accuracy: 0.0001)
            }
            canvas.removeFromSuperview()
        }
    }

    @MainActor
    func testUnavailableCanvasReturnsNil() {
        XCTAssertNil(PhotoSpaceViewModel.screenPercentToCanvasCoordinates(
            xPercent: 0.5, yPercent: 0.5,
            capturedDisplayFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            canvasView: NSView()
        ))
    }
}
