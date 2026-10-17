import AppKit
import Combine
import Foundation

/// The recovered API uses WebSocket notifications and an HTTP placement response.
@MainActor
final class Websocket: ObservableObject {
    @Published private(set) var status = "Disconnected"
    @Published private(set) var lastError: String?
    @Published private(set) var isConnected = false

    var onClipReceive: (NetworkClip, CGRect) -> Void = { _, _ in }
    var capture: () async throws -> ScreenCapture.Result = { try await ScreenCapture.takeScreenshot() }

    private let session: URLSession
    private var connection: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var completedIDs: [String] = []

    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 120
        self.session = session ?? URLSession(configuration: configuration)
    }

    func connect(to endpoint: APIEndpoint) {
        disconnect()
        lastError = nil
        connection = Task { [weak self] in
            await self?.runConnection(endpoint: endpoint)
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isConnected = false
        status = "Disconnected"
    }

    private func runConnection(endpoint: APIEndpoint) async {
        var retryDelay: Double = 1
        while !Task.isCancelled {
            status = "Connecting…"
            let current = session.webSocketTask(with: endpoint.websocketURL)
            current.maximumMessageSize = 16_384
            socket = current
            current.resume()
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    current.sendPing { error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume() }
                    }
                }
                try Task.checkCancellation()
                isConnected = true
                status = "Connected · waiting for phone"
                lastError = nil
                retryDelay = 1

                while !Task.isCancelled {
                    let message = try await current.receive()
                    try Task.checkCancellation()
                    let data: Data
                    switch message {
                    case .string(let text): data = Data(text.utf8)
                    case .data(let bytes): data = bytes
                    @unknown default: continue
                    }
                    do {
                        let trigger = try JSONDecoder().decode(ReceiveSocketData.self, from: data)
                        guard trigger.message == "trigger" else { continue }
                        guard let id = trigger.id, !id.isEmpty else {
                            throw PhotoDropError.message("The server sent a trigger without an event ID.")
                        }
                        guard !completedIDs.contains(id) else { continue }
                        await handleTrigger(id: id, endpoint: endpoint)
                    } catch {
                        report(error)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                report(error)
            }
            current.cancel(with: .goingAway, reason: nil)
            isConnected = false
            status = "Reconnecting in \(Int(retryDelay))s…"
            do { try await Task.sleep(for: .seconds(retryDelay)) }
            catch { return }
            retryDelay = min(retryDelay * 2, 30)
        }
    }

    private func handleTrigger(id: String, endpoint: APIEndpoint) async {
        do {
            status = "Capturing display…"
            let screenshot = try await capture()
            try Task.checkCancellation()
            status = "Finding placement…"
            let clip = try await upload(id: id, screenshot: screenshot.jpegData, endpoint: endpoint)
            try Task.checkCancellation()
            onClipReceive(clip, screenshot.displayFrame)
            completedIDs.append(id)
            if completedIDs.count > 100 { completedIDs.removeFirst() }
            lastError = nil
            status = "Connected · clip received"
        } catch {
            guard !Task.isCancelled else { return }
            report(error)
            status = "Connected · transfer failed"
        }
    }

    /// Tests the wire contract independently of screen-recording permission.
    func upload(id: String, screenshot: Data, endpoint: APIEndpoint) async throws -> NetworkClip {
        var request = URLRequest(url: endpoint.uploadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = try JSONEncoder().encode(SendData(id: id, img: screenshot.base64EncodedString()))
        let (data, response) = try await session.upload(for: request, from: body)
        guard let response = response as? HTTPURLResponse else {
            throw PhotoDropError.message("The server returned an invalid HTTP response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw PhotoDropError.message("Server returned HTTP \(response.statusCode)\(detail.map { ": \($0)" } ?? "").")
        }
        let clip = try JSONDecoder().decode(NetworkClip.self, from: data)
        guard clip.x.isFinite, clip.y.isFinite else {
            throw PhotoDropError.message("The server returned invalid placement coordinates.")
        }
        guard decodeBase64ToImage(base64Image: clip.clip) != nil else {
            throw PhotoDropError.message("The server returned an invalid clip image.")
        }
        return clip
    }

    private func report(_ error: Error) {
        lastError = error.localizedDescription
        NSLog("PhotoDrop: %@", error.localizedDescription)
    }
}
