//
//  S3Service.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/7/26.
//

import Foundation
import SwiftUI
import os

enum ImageType: String {
    case jpeg = "image/jpeg"
    case png = "image/png"
}

struct S3Service {
    var session: URLSession = .shared
    
    func uploadImage(image: Data, uploadURL: String, contentType: ImageType = .jpeg) async throws {
        let url = try uploadURL.toURL()
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.put.rawValue
        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        
        let (body, response) = try await session.upload(for: request, from: image)
        try validate(response, body: body)
    }
    
    func downloadImage(from downloadURL: String, contentType: ImageType = .jpeg) async throws -> Data{
        let url = try downloadURL.toURL()
        let (body, response) = try await session.data(from: url)
        try validate(response, body: body)
        return body
    }

    private func validate(_ response: URLResponse, body: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: body)
        }
    }
}

extension String {
    func toURL() throws -> URL {
        guard var urlComponents = URLComponents(string: self) else {
            throw APIError.invalidURL
        }
        
        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }
        
        return url
    }
}
