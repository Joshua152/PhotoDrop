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
    
    private(set) var status: CameraStatus = CameraStatus.unknown
    
    private(set) var captureActivity: CaptureActivity = CaptureActivity.idle
    
    private(set) var shouldFlashScreen = false
    
    private(set) var error: Error?
    
    var previewSource: PreviewSource { captureService.previewSource }
    
    var clip: UIImage?
    
    private let captureService = CaptureService()
        
    init() {
    }
    
    func start() async {
        guard await captureService.isAuthorized else {
            status = .unauthorized
            return
        }
        
        do {
            try await captureService.start()
            observeState()
            status = .running
        } catch {
            logger.error("Failed to start capture service. \(error)")
            status = .failed
        }
    }
    
    func capturePhoto() async -> Photo? {
        do {
            return try await captureService.capturePhoto()
        } catch {
            self.error = error
        }
        return nil
    }
    
    func captureClip() async {
        let photo = await capturePhoto()
        if photo == nil {
            logger.error("Failed to capture photo for clip.")
        }
        
        clip = await extractClip(from: photo!)
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
