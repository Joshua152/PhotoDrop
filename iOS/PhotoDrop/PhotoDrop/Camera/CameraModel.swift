//
//  CameraModel.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import SwiftUI
import os
import Combine

@Observable
final class CameraModel: Camera {
    
    private(set) var clipStatus: ClipStatus = ClipStatus.waitingForClip
    private(set) var cameraStatus: CameraStatus = CameraStatus.unknown
    
    private(set) var captureActivity: CaptureActivity = CaptureActivity.idle
    
    private(set) var shouldFlashScreen = false
    
    private(set) var error: Error?
    
    var previewSource: PreviewSource { captureService.previewSource }
    
    var clip: UIImage?
    
    private let captureService = CaptureService()
    
    private let api = APIClient(baseURL: "https://gateway-fun-mass-determination.trycloudflare.com")
    private let s3Service = S3Service()
    private var uploadURLs: UploadURLs?
        
    init() {
    }
    
    func start() async {
        guard await captureService.isAuthorized else {
            cameraStatus = .unauthorized
            return
        }
        
        do {
            try await captureService.start()
            observeState()
            cameraStatus = .running
        } catch {
            logger.error("Failed to start capture service. \(error)")
            cameraStatus = .failed
        }
    }
    
    func handlePhotoAction() async {
        switch clipStatus {
        case .waitingForClip:
            await handleClipAction()
        case .waitingForPasteLoc:
            await handlePasteLocAction()
        }
    }
    
    func handleClipAction() async {
        guard let clip = await captureClip(),
              let clipPng = clip.pngData() else {
            return
        }
        self.clip = clip
        
        do {
            uploadURLs = try await api.getUploadURLs()
        } catch {
            logger.error("Failed to get upload URLs. \(error)")
            self.error = error
            return
        }
        
        guard let uploadURLs = uploadURLs else { return }
        
        do {
            try await s3Service.uploadImage(image: clipPng, uploadURL: uploadURLs.clipUploadURL, contentType: .png)
            try await api.notifyClipUploaded(id: uploadURLs.id)
        } catch {
            logger.error("Failed to upload clip to S3 and notify server. \(error)")
            self.error = error
            return
        }
        
        clipStatus = .waitingForPasteLoc
    }
    
    func handlePasteLocAction() async {
        guard let uploadURLs = uploadURLs else {
            logger.log("Missing upload URLs.")
            return
        }
        
        guard let photo = await capturePhoto() else { return }

        do {
            // Defaults to jpeg format
            try await s3Service.uploadImage(image: photo.data, uploadURL: uploadURLs.computerPictureUploadURL)
            try await api.notifyComputerPictureUploaded(id: uploadURLs.id)
        } catch {
            logger.error("Failed to upload computer photo to S3. \(error)")
            self.error = error
            return
        }
        
        clip = nil
        clipStatus = .waitingForClip
    }
    
    private func capturePhoto() async -> Photo? {
        do {
            return try await captureService.capturePhoto()
        } catch {
            logger.error("Failed to capture photo.")
            self.error = error
        }
        return nil
    }
    
    private func captureClip() async -> UIImage? {
        let photo = await capturePhoto()
        if photo == nil {
            logger.error("Failed to capture photo for clip.")
        }
        
        return await extractClip(from: photo!)
    }
    
    private func extractClip(from image: Photo) async -> UIImage? {
        guard let stickerCG = await extractForeground(from: image) else { return nil }
        let stickerImage = UIImage(cgImage: stickerCG)
        
        return stickerImage
    }
    
    func focusAndExpose(at point: CGPoint) async {
        await captureService.focusAndExpose(at: point)
    }
            
    private func flashScreen() {
        shouldFlashScreen = true
        withAnimation(.linear(duration: 0.01)) {
            shouldFlashScreen = false
        }
    }
    
    private func observeState() {
        Task {
            for await activity in await captureService.$captureActivity.values {
                if activity.willCapture {
                    flashScreen()
                } else {
                    captureActivity = activity
                }
            }
        }
    }
}
