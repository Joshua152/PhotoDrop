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

    var uploadURL: URL { baseURL.appendingPathComponent("computer-send") }

    var websocketURL: URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("computer"), resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme?.lowercased() == "https" ? "wss" : "ws"
        return components.url!
    }
}

struct SendData: Encodable {
    var id: String
    var img: String
}

struct NetworkClip: Decodable {
    let x: Double
    let y: Double
    let clip: String
}

struct ReceiveSocketData: Decodable {
    let message: String
    let id: String?
}

enum PhotoDropError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}
