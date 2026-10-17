import AppKit
import XCTest
@testable import PhotoDrop

@MainActor
final class WebSocketIntegrationTests: XCTestCase {
    func testTriggerCaptureUploadAndPlacementSurvivesBadMessageAndReconnect() async throws {
        guard let server = ProcessInfo.processInfo.environment["PHOTODROP_TEST_SERVER"] else {
            throw XCTSkip("Run mac/scripts/test-integration.sh to include the local WebSocket test.")
        }
        let delivered = expectation(description: "Clip delivered after trigger")
        delivered.expectedFulfillmentCount = 2
        let websocket = Websocket()
        let display = CGRect(x: -1440, y: 200, width: 1440, height: 900)
        var captureCount = 0
        websocket.capture = {
            captureCount += 1
            return ScreenCapture.Result(jpegData: Data([1, 2, 3]), pngData: Data(), displayFrame: display)
        }
        websocket.onClipReceive = { clip, capturedFrame in
            XCTAssertEqual(clip.x, 0.4)
            XCTAssertEqual(clip.y, 0.6)
            XCTAssertEqual(capturedFrame, display)
            XCTAssertNotNil(decodeBase64ToImage(base64Image: clip.clip))
            delivered.fulfill()
        }
        defer { websocket.disconnect() }
        websocket.connect(to: try APIEndpoint(server))
        await fulfillment(of: [delivered], timeout: 20)
        // One new event before and one after a dropped socket. The duplicate
        // first event after reconnection must not cause a third screenshot.
        XCTAssertEqual(captureCount, 2)
        websocket.disconnect()
        XCTAssertFalse(websocket.isConnected)
        XCTAssertEqual(websocket.status, "Disconnected")
    }
}
