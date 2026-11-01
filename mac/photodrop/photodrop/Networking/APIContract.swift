import Foundation

struct APIEndpoint {
    let baseURL: URL

    init(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw PhotoDropError.message("Enter an HTTP or HTTPS server URL, such as http://localhost:8000.")
        }
        baseURL = url
    }

    var calculateClipURL: URL { baseURL.appendingPathComponent("computer/calculate-clip-location") }

    var websocketURL: URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("computer"), resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme?.lowercased() == "https" ? "wss" : "ws"
        return components.url!
    }
}

struct CalculateLocationData: Encodable {
    var id: String
}

struct ClipLocation: Decodable {
    let x: Double
    let y: Double
}

struct ReceiveSocketData: Decodable {
    let message: String
    let id: String
    let clipDownloadURL: String?
    let ssUploadURL: String?

    enum CodingKeys: String, CodingKey {
        case message, id
        case clipDownloadURL = "clip_download_url"
        case ssUploadURL = "ss_upload_url"
    }
}

enum PhotoDropError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}
