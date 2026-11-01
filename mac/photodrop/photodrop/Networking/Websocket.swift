import AppKit
import Combine
import Foundation

/// The recovered API uses WebSocket notifications and an HTTP placement response.
@MainActor
final class Websocket: ObservableObject {
    @Published private(set) var status = "Disconnected"
    @Published private(set) var lastError: String?
    @Published private(set) var isConnected = false

    var onClipReceive: (Data, ClipLocation, CGRect) -> Void = { _, _, _ in }
    var capture: () async throws -> ScreenCapture.Result = { try await ScreenCapture.takeScreenshot() }

    private let session: URLSession
    private var connection: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var completedIDs: [String] = []
    private struct PendingTransfer {
        var clip: Data?
        var location: ClipLocation?
        var displayFrame: CGRect?
    }

    private var pendingTransfers: [String: PendingTransfer] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var placementTasks: [String: Task<Void, Never>] = [:]

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
        for task in downloadTasks.values { task.cancel() }
        for task in placementTasks.values { task.cancel() }
        downloadTasks.removeAll()
        placementTasks.removeAll()
        pendingTransfers.removeAll()
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
                        let id = trigger.id
                        guard !completedIDs.contains(id) else { continue }
                        
                        switch trigger.message {
                        case "download_clip":
                            guard let downloadURL = trigger.clipDownloadURL else {
                                throw PhotoDropError.message("Missing clip_download_url in download_clip message.")
                            }
                            guard downloadTasks[id] == nil, pendingTransfers[id]?.clip == nil else { continue }
                            downloadTasks[id] = Task { [weak self] in
                                guard let self else { return }
                                defer { if !Task.isCancelled { self.downloadTasks[id] = nil } }
                                await self.downloadClip(id: id, downloadURL: downloadURL)
                            }
                        case "screenshot":
                            guard let uploadURL = trigger.ssUploadURL else {
                                throw PhotoDropError.message("Missing ss_upload_url in screenshot message.")
                            }
                            guard placementTasks[id] == nil, pendingTransfers[id]?.location == nil else { continue }
                            placementTasks[id] = Task { [weak self] in
                                guard let self else { return }
                                defer { if !Task.isCancelled { self.placementTasks[id] = nil } }
                                await self.screenshotAndGetPosition(id: id, uploadURL: uploadURL, apiEndpoint: endpoint)
                            }
                        default:
                            continue
                        }
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
    
    private func downloadClip(id: String, downloadURL: String) async {
        guard pendingTransfers[id]?.clip == nil else { return }
        do {
            guard let url = URL(string: downloadURL),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty else {
                throw PhotoDropError.message("The server returned an invalid clip download URL.")
            }
            status = "Downloading clip…"
            let (data, response) = try await session.data(from: url)
            try Task.checkCancellation()
            guard let response = response as? HTTPURLResponse else {
                throw PhotoDropError.message("The server returned an invalid HTTP response.")
            }
            guard (200..<300).contains(response.statusCode) else {
                throw PhotoDropError.message("Clip download returned HTTP \(response.statusCode).")
            }
            guard let image = NSImage(data: data),
                  image.size.width > 0, image.size.height > 0 else {
                throw PhotoDropError.message("The server returned an invalid clip image.")
            }
            pendingTransfers[id, default: PendingTransfer()].clip = data
            lastError = nil
            status = "Connected · waiting for placement"
            deliverIfReady(id: id)
        } catch {
            guard !Task.isCancelled else { return }
            report(error)
            status = "Connected · download failed"
        }
    }
    
    private func screenshotAndGetPosition(id: String, uploadURL: String, apiEndpoint: APIEndpoint) async {
        do {
            status = "Capturing display…"
            let screenshot = try await capture()
            try Task.checkCancellation()
            
            status = "Uploading screenshot…"
            // TODO: send small version of screenshot
            try await upload(id: id, screenshot: screenshot.jpegData, endpoint: uploadURL)
            try Task.checkCancellation()
                        
            status = "Caculating position…"
            let clipLocation = try await getLocation(id: id, apiEndpoint: apiEndpoint)
            try Task.checkCancellation()
            
            pendingTransfers[id, default: PendingTransfer()].location = clipLocation
            pendingTransfers[id, default: PendingTransfer()].displayFrame = screenshot.displayFrame
            lastError = nil
            status = "Connected · waiting for clip"
            deliverIfReady(id: id)
        } catch {
            guard !Task.isCancelled else { return }
            report(error)
            status = "Connected · transfer failed"
        }
    }

    private func deliverIfReady(id: String) {
        guard !completedIDs.contains(id),
              let transfer = pendingTransfers[id],
              let clip = transfer.clip,
              let location = transfer.location,
              let displayFrame = transfer.displayFrame else { return }

        pendingTransfers.removeValue(forKey: id)
        completedIDs.append(id)
        if completedIDs.count > 100 { completedIDs.removeFirst() }
        onClipReceive(clip, location, displayFrame)
        lastError = nil
        status = "Connected · clip received"
    }

    /// Tests the wire contract independently of screen-recording permission.
    private func upload(id: String, screenshot: Data, endpoint: String) async throws {
        guard let url = URL(string: endpoint),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty else {
            throw PhotoDropError.message("The server returned an invalid screenshot upload URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.upload(for: request, from: screenshot)
        guard let response = response as? HTTPURLResponse else {
            throw PhotoDropError.message("The server returned an invalid HTTP response.")
        }
        guard (200..<300).contains(response.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw PhotoDropError.message("Server returned HTTP \(response.statusCode)\(detail.map { ": \($0)" } ?? "").")
        }
    }

    private func getLocation(id: String, apiEndpoint: APIEndpoint) async throws -> ClipLocation {
        let url = apiEndpoint.calculateClipURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let bodyData = CalculateLocationData(id: id)
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(bodyData)
        } catch {
            print("Failed to encode JSON: \(error.localizedDescription)")
            throw PhotoDropError.message("Unable to encode request JSON for getLocation")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw PhotoDropError.message("Server error or invalid response status")
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(ClipLocation.self, from: data)
            return result
        } catch {
            throw PhotoDropError.message("Network request failed: \(error.localizedDescription)")
        }
    }
    
    private func report(_ error: Error) {
        lastError = error.localizedDescription
        NSLog("PhotoDrop: %@", error.localizedDescription)
    }
}
