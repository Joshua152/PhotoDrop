import AppKit
import XCTest
@testable import PhotoDrop

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@MainActor
final class NetworkTests: XCTestCase {
    private func client() -> Websocket {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return Websocket(session: URLSession(configuration: configuration))
    }

    private func png() throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<2 {
            for y in 0..<2 { bitmap.setColor(NSColor(deviceRed: 1, green: 0, blue: 0, alpha: 0.5), atX: x, y: y) }
        }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }

    func testEndpointSchemesAndPrefix() throws {
        let local = try APIEndpoint(" http://localhost:8000/ \n")
        XCTAssertEqual(local.websocketURL.absoluteString, "ws://localhost:8000/computer")
        XCTAssertEqual(local.uploadURL.absoluteString, "http://localhost:8000/computer-send")
        let remote = try APIEndpoint("https://example.com/api")
        XCTAssertEqual(remote.websocketURL.absoluteString, "wss://example.com/api/computer")
        XCTAssertEqual(remote.uploadURL.path, "/api/computer-send")
        for bad in ["", "localhost:8000", "ftp://server", "http://", "https://user:pass@host", "http://host?q=1"] {
            XCTAssertThrowsError(try APIEndpoint(bad), bad)
        }
    }

    func testUploadUsesOriginalJSONContractAndDecodesPNGAlpha() async throws {
        let imageData = try png()
        let response = try JSONSerialization.data(withJSONObject: ["x": 0.4, "y": 0.6, "clip": imageData.base64EncodedString()])
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/computer-send")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
            }
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(json["id"], "event-123")
            XCTAssertEqual(json["img"], Data([1, 2, 3]).base64EncodedString())
            return (200, response)
        }
        defer { MockURLProtocol.handler = nil }
        let result = try await client().upload(id: "event-123", screenshot: Data([1, 2, 3]), endpoint: APIEndpoint("http://localhost:8000"))
        XCTAssertEqual(result.x, 0.4)
        XCTAssertEqual(result.y, 0.6)
        let decoded = try XCTUnwrap(decodeBase64ToImage(base64Image: result.clip))
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(decoded.tiffRepresentation)))
        XCTAssertTrue(bitmap.hasAlpha)
        XCTAssertEqual(try XCTUnwrap(bitmap.colorAt(x: 0, y: 0)).alphaComponent, 0.5, accuracy: 0.02)
    }

    func testHTTPFailureRetainsAPIError() async throws {
        MockURLProtocol.handler = { _ in (400, Data(#"{"detail":"Event ID not found"}"#.utf8)) }
        defer { MockURLProtocol.handler = nil }
        do {
            _ = try await client().upload(id: "missing", screenshot: Data(), endpoint: APIEndpoint("http://localhost:8000"))
            XCTFail("Expected HTTP failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("400"))
            XCTAssertTrue(error.localizedDescription.contains("Event ID not found"))
        }
    }

    func testInvalidClipIsRejected() async throws {
        MockURLProtocol.handler = { _ in (200, Data(#"{"x":0.4,"y":0.6,"clip":"not an image"}"#.utf8)) }
        defer { MockURLProtocol.handler = nil }
        do {
            _ = try await client().upload(id: "bad", screenshot: Data(), endpoint: APIEndpoint("http://localhost:8000"))
            XCTFail("Expected invalid clip failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("invalid clip")) }
        XCTAssertNil(decodeBase64ToImage(base64Image: "!!!"))
    }

    func testAndroidLineWrappedBase64IsAccepted() throws {
        let encoded = try png().base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        XCTAssertNotNil(decodeBase64ToImage(base64Image: encoded))
    }
}
