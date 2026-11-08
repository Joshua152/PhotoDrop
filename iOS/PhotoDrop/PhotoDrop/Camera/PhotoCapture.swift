//
//  PhotoCapture.swift
//  PhotoDrop
//
//  Created by Joshua Au on 11/2/26.
//

import AVFoundation
import CoreImage
import Combine
import os

enum PhotoCapureError: Error {
    case noPhotoData
}

nonisolated final class PhotoCapture {
    @Published private(set) var captureActivity: CaptureActivity = .idle
        
    let output = AVCapturePhotoOutput()
    
    func capturePhoto() async throws -> Photo {
        try await withCheckedThrowingContinuation { continuation in
            let photoSettings = createPhotoSettings()
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            monitorProgress(of: delegate)
            output.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }
    
    func setVideoRotationAngle(_ angle: CGFloat) {
        output.connection(with: .video)?.videoRotationAngle = angle
    }
    
    private func createPhotoSettings() -> AVCapturePhotoSettings {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        
        photoSettings.maxPhotoDimensions = output.maxPhotoDimensions
        photoSettings.photoQualityPrioritization = .speed
        
        return photoSettings
    }
    
    private func monitorProgress(of delegate: PhotoCaptureDelegate, isolation: isolated (any Actor)? = #isolation) {
        Task {
            _ = isolation
            for await activity in delegate.activityStream {
                captureActivity = activity
            }
        }
    }
}

typealias PhotoContinuation = CheckedContinuation<Photo, Error>

nonisolated private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: PhotoContinuation
    
    private var isProxyPhoto = false
    private var photoData: Data?
    
    let activityStream: AsyncStream<CaptureActivity>
    private let activityContinuation: AsyncStream<CaptureActivity>.Continuation
    
    init(continuation: PhotoContinuation) {
        self.continuation = continuation
        
        let (activityStream, activityContinuation) = AsyncStream.makeStream(of: CaptureActivity.self)
        self.activityStream = activityStream
        self.activityContinuation = activityContinuation
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Signal that a capture is beginning
        activityContinuation.yield(.photoCapture(willCapture: true))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: Error?) {
        if let error = error {
            logger.debug("Error capturing deferred photo: \(error)")
            return
        }
        
        // Capture the data for this photo
        photoData = deferredPhotoProxy?.fileDataRepresentation()
        isProxyPhoto = true
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.debug("Error capturing photo: \(String(describing: error))")
            return
        }
        photoData = photo.fileDataRepresentation()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        defer {
            // Finish the continuation to terminate the activity steam
            activityContinuation.finish()
        }
        
        if let error {
            continuation.resume(throwing: error)
            return
        }
        
        guard let photoData else {
            continuation.resume(throwing: PhotoCapureError.noPhotoData)
            return
        }
        
        let photo = Photo(data: photoData, isProxy: isProxyPhoto)
        continuation.resume(returning: photo)
    }
}
