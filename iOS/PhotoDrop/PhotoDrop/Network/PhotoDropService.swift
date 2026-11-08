//
//  PhotoDropService.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/7/26.
//

// MARK: - GET /phone/upload-urls
struct UploadURLs: Decodable {
    let id: String
    let clipUploadURL: String
    let computerPictureUploadURL: String
    
    // The keys will get converted to snake case in the APIClient
    enum CodingKeys: String, CodingKey {
        case id
        case clipUploadURL = "clipUploadUrl"
        case computerPictureUploadURL = "computerPictureUploadUrl"
    }
}

// MARK: - POST /phone/notify-clip-uploaded
struct ClipUploadRequest: Encodable {
    let id: String
}

// MARK: - POST /phone/notify-computer-picture-uploaded
struct ComputerPictureUpload: Encodable {
    let id: String
}

// MARK: - Endpoints
extension APIClient {
    func getUploadURLs() async throws -> UploadURLs {
        try await request(path: "/phone/upload-urls")
    }
    
    func notifyClipUploaded(id: String) async throws {
        let requestBody = ClipUploadRequest(id: id)
        try await requestNoContent(path: "/phone/notify-clip-uploaded", method: .post, body: requestBody)
    }
    
    func notifyComputerPictureUploaded(id: String) async throws {
        let requestBody = ComputerPictureUpload(id: id)
        try await requestNoContent(path: "/phone/notify-computer-picture-uploaded", method: .post, body: requestBody)
    }
}
